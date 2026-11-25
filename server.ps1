param([switch]$NoBrowser, [int]$Port = 0, [string]$DataRoot = '')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$base = $PSScriptRoot
$dataBase = if ($DataRoot) { [IO.Path]::GetFullPath($DataRoot) } else { $base }
$pagePath = Join-Path $base '星铁遗器整理助手.html'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$token = [Guid]::NewGuid().ToString('N')
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
$listenPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$origin = 'http://127.0.0.1:' + $listenPort
$capture = $null
$markerJob = $null
$stopRequested = $false
$lastRequest = Get-Date
$releaseUrl = 'https://github.com/IceDynamix/reliquary-archiver/releases/download/v0.20.0/reliquary-archiver-pktmon-x64.exe'
$expectedHash = 'ce4a5bb00ba0c3d681772d9151ac2332934dd1b497926c3d7994f40c2a94cd9d'

function Send-Response($stream, [int]$status, [string]$content, [string]$contentType = 'application/json; charset=utf-8') {
    $bytes = $utf8.GetBytes($content)
    $reason = switch ($status) {200 {'OK'} 204 {'No Content'} 400 {'Bad Request'} 403 {'Forbidden'} 404 {'Not Found'} 405 {'Method Not Allowed'} 409 {'Conflict'} default {'Internal Server Error'}}
    $headers = "HTTP/1.1 $status $reason`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nReferrer-Policy: no-referrer`r`n`r`n"
    $head = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $stream.Write($head, 0, $head.Length)
    if ($bytes.Length -gt 0) { $stream.Write($bytes, 0, $bytes.Length) }
    $stream.Flush()
}

function Json($obj) { return ConvertTo-Json -InputObject $obj -Depth 40 -Compress }

function Read-LocalRequest($stream) {
    $headerBytes=New-Object IO.MemoryStream
    $tail=0
    while($true){$b=$stream.ReadByte();if($b -lt 0){throw '请求提前结束'};$headerBytes.WriteByte([byte]$b);$tail=(($tail -shl 8) -bor $b) -band 0xffffffffL;if($tail -eq 0x0d0a0d0a){break};if($headerBytes.Length -gt 16384){throw '请求头过大'}}
    $lines=[Text.Encoding]::ASCII.GetString($headerBytes.ToArray()).Split(@("`r`n"),[StringSplitOptions]::None)
    $headerBytes.Dispose();$pieces=$lines[0].Split(' ');if($pieces.Count -lt 2){throw '请求格式无效'}
    $headers=@{};foreach($line in $lines[1..($lines.Length-1)]){$colon=$line.IndexOf(':');if($colon -gt 0){$headers[$line.Substring(0,$colon).ToLowerInvariant()]=$line.Substring($colon+1).Trim()}}
    $length=0;if($headers['content-length']){if(-not [int]::TryParse($headers['content-length'],[ref]$length) -or $length -lt 0 -or $length -gt 6291456){throw '请求体过大或长度无效'}}
    $bytes=New-Object byte[] $length;$offset=0;while($offset -lt $length){$n=$stream.Read($bytes,$offset,$length-$offset);if($n -le 0){throw '请求体不完整'};$offset+=$n}
    return @{method=$pieces[0];route=$pieces[1].Split('?')[0];headers=$headers;body=$utf8.GetString($bytes)}
}

function Get-MarkerStatus {
    $ready=$true # Fixed 1920x1080 layout replaces manual calibration.
    if(-not $script:markerJob){return @{state='idle';calibrated=$ready;message='尚未启动游戏内标记。'}}
    $file=Join-Path $script:markerJob.directory 'status.json'
    if(Test-Path -LiteralPath $file){try{$state=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8));if($state.state -in @('starting','calibrating','running')){try{if($script:markerJob.process.HasExited){$state.state='failed';$state.message='标记进程意外结束，请检查 marker-runs 记录后重试。'}}catch{}};$state|Add-Member -NotePropertyName calibrated -NotePropertyValue $ready -Force;return $state}catch{}}
    if(((Get-Date)-$script:markerJob.started).TotalSeconds -gt 25){
        try{if($script:markerJob.process.HasExited){return @{state='failed';calibrated=$ready;message='标记进程启动失败，请查看 marker-runs 中的记录或重试。'}}}catch{}
    }
    return @{state='starting';calibrated=$ready;message='正在等待管理员授权并准备本机识别…'}
}

function Assert-MarkerIdle {
    $state=Get-MarkerStatus
    if($state.state -in @('running','starting','calibrating')){throw '标记或校准正在进行，请先停止当前任务。'}
}

function Start-MarkerWorker([string]$Mode,$Plan,[bool]$Preview) {
    if($Mode -ne 'Run'){throw '本版本自动定位，不再需要手动校准。'}
    Assert-MarkerIdle
    $jobId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $dir=Join-Path (Join-Path $dataBase 'marker-runs') $jobId
    [IO.Directory]::CreateDirectory($dir)|Out-Null
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $base 'marker.ps1')+'" -Mode '+$Mode+' -JobDirectory "'+$dir+'" -DataRoot "'+$dataBase+'"'
    if($Mode -eq 'Run'){
        $planFile=Join-Path $dir 'plan.json'
        [IO.File]::WriteAllText($planFile,(ConvertTo-Json $Plan -Depth 40 -Compress),$utf8)
        $args+=' -PlanPath "'+$planFile+'"';if($Preview){$args+=' -PreviewOnly'}
    }
    $process=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -WindowStyle Hidden -PassThru
    $script:markerJob=@{id=$jobId;directory=$dir;process=$process;started=Get-Date}
    return @{state='starting';jobId=$jobId;message='已启动，请按游戏内提示操作。'}
}

function Get-CanonicalMarkerStat([string]$Stat){
    if($Stat -in @('HP_','ATK_','DEF_')){return $Stat.TrimEnd('_')+'%'}
    return $Stat.TrimEnd('_')
}

function Get-CanonicalMarkerMainStat([string]$Stat,[string]$Slot){
    $key=Get-CanonicalMarkerStat $Stat
    if(($Slot -replace '\s','') -in @('Body','Feet','PlanarSphere','LinkRope') -and $key -in @('HP','ATK','DEF')){$key+='%'}
    return $key
}

function Get-MarkerVisibleValue([string]$Stat,[double]$Value){
    if($Stat -in @('HP','ATK','DEF','SPD')){return [Math]::Floor($Value+0.00001)}
    return [Math]::Floor($Value*10+0.00001)/10
}

function Validate-MarkerPlan($Plan) {
    if(-not $script:capture -or $script:capture.state -ne 'complete' -or $Plan.captureId -ne $script:capture.id){throw '请先用“一键读取背包”重新读取本次账号，再开始自动标记。'}
    if(((Get-Date)-$script:capture.started).TotalMinutes -gt 30){throw '背包快照已超过 30 分钟，请重新读取后标记。'}
    if($Plan.schema -ne 'hsr-marker-plan-v1' -or $Plan.allowSalvage -ne $false -or @($Plan.candidates).Count -lt 1 -or @($Plan.candidates).Count -gt 3000){throw '标记清单无效。'}
    $snapshot=ConvertFrom-Json $script:capture.json
    if($Plan.inventoryCount -ne @($snapshot.relics).Count -or $Plan.inventoryCount -gt 3000){throw '背包总数与本次快照不一致，请重新读取。'}
    $inventory=@{};foreach($r in $snapshot.relics){$id=[string]$r._uid;if($inventory.ContainsKey($id)){throw '原始背包含重复 ID，请重新读取。'};$inventory[$id]=$r}
    $data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source\data.json'),$utf8))
    $seen=@{};$seenIds=@{};$total=0
    foreach($c in $Plan.candidates){
        if(-not $c.key -or $seen.ContainsKey([string]$c.key)){throw '标记指纹不完整或重复。'};$seen[[string]$c.key]=$true
        if($c.count -ne @($c.ids).Count -or $c.count -lt 1){throw '标记数量不一致。'}
        $piece=$data.pieceNames.([string]$c.setId).([string]$c.part)
        if(-not $piece -or $piece -ne $c.pieceName -or $data.sets.([string]$c.setId).name -ne $c.setName){throw '遗器名称与内置资料不匹配。'}
        foreach($id in $c.ids){
            if($seenIds.ContainsKey([string]$id)){throw '候选 ID 重复，请重新筛选。'};$seenIds[[string]$id]=$true
            $r=$inventory[[string]$id]
            if(-not $r -or $r.rarity -ne 5 -or $r.lock -ne $false -or $r.discard -ne $false -or $r.location -cne '' -or $r.level -ne $c.enhance -or [string]$r.set_id -ne [string]$c.setId -or ($r.slot -replace '\s','') -ne $c.part){throw '候选与新背包不一致，或已锁定、装备、弃置，请重新读取。'}
            if((Get-CanonicalMarkerMainStat $r.mainstat $r.slot) -ne $c.main.stat){throw '主属性与新背包不一致。'}
            # A visual group can contain 3 active + 1 preview or 4 active stats.
            # The frontend only groups items when every member has the same low-score decision.
            # Validate the complete visible fingerprint, including preview values.
            $allVisual=@($r.substats)+@($r.preview_substats|Where-Object{$null -ne $_})
            if(@($c.visualSubstats).Count -ne $allVisual.Count){throw '预览词条数量与背包不一致。'}
            foreach($sub in $c.visualSubstats){$raw=@($allVisual|Where-Object{(Get-CanonicalMarkerStat $_.key) -eq $sub.stat});if($raw.Count -ne 1 -or [Math]::Abs((Get-MarkerVisibleValue $sub.stat $raw[0].value)-(Get-MarkerVisibleValue $sub.stat $sub.value)) -gt 0.0001){throw '预览词条与背包不一致。'}}
            $total++
        }
    }
    if($total -ne $Plan.total -or $total -gt 3000){throw '候选总数无效。'}
    return $true
}

function Start-Capture {
    if ($script:capture -and $script:capture.state -eq 'running') {
        throw '上一次读取仍在进行，请稍候。'
    }
    $toolsDir = Join-Path $dataBase 'tools'
    $captureDir = Join-Path $dataBase 'captures'
    [System.IO.Directory]::CreateDirectory($toolsDir) | Out-Null
    [System.IO.Directory]::CreateDirectory($captureDir) | Out-Null
    $exe = Join-Path $toolsDir 'reliquary-archiver-pktmon-x64.exe'
    $bundled = Join-Path $base 'tools\reliquary-archiver-pktmon-x64.exe'
    if (Test-Path -LiteralPath $bundled) { $exe = $bundled }
    if (-not (Test-Path -LiteralPath $exe)) {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $partial = $exe + '.part'
        try {
            Invoke-WebRequest -Uri $releaseUrl -OutFile $partial -UseBasicParsing -TimeoutSec 100
            $hash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $expectedHash) { throw 'Reliquary 下载校验失败，请从官方发布页重新下载指定版本。' }
            Move-Item -LiteralPath $partial -Destination $exe -Force
        } catch {
            if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
            throw ('无法准备 Reliquary：' + $_.Exception.Message + '。可以手动下载 v0.20.0 的 pktmon-x64 版本放入 tools 文件夹，或直接导入 JSON。')
        }
    }
    if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
        throw 'tools 文件夹中的 Reliquary 不是已校验的 v0.20.0 PktMon 版本。请使用官方对应版本，或手动导出 JSON 后导入。'
    }
    $name = '背包-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
    $output = Join-Path $captureDir ($name + '.json')
    $log = Join-Path $captureDir ($name + '.log')
    $arguments = '--headless --exit-after-capture --timeout 180 --no-update --log-path "' + $log + '" "' + $output + '"'
    try {
        $process = Start-Process -FilePath $exe -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru
    } catch {
        throw ('读取未启动：' + $_.Exception.Message + '。读取登录流量需要管理员授权。')
    }
    $script:capture = @{id=$name;state='running'; process=$process; output=$output; started=Get-Date; message='Reliquary 已启动。请从游戏登录界面点击进入游戏，等候自动读取。'}
    return @{state='running'; message=$script:capture.message}
}

function Capture-Status {
    if (-not $script:capture) { return Json @{state='idle'; message='尚未启动读取。'} }
    $c = $script:capture
    if ($c.state -eq 'complete') { return '{"state":"complete","captureId":'+(Json $c.id)+',"data":' + $c.json + '}' }
    if ($c.state -eq 'failed') { return Json @{state='failed'; message=$c.message} }
    if (Test-Path -LiteralPath $c.output) {
        try {
            $raw = [System.IO.File]::ReadAllText($c.output, $utf8)
            $parsed = ConvertFrom-Json -InputObject $raw
            if ($null -ne $parsed.relics) {
                $c.state = 'complete'; $c.json = $raw
                return '{"state":"complete","captureId":'+(Json $c.id)+',"data":' + $raw + '}'
            }
        } catch { }
    }
    $exited = $false
    try { $c.process.Refresh(); $exited = $c.process.HasExited } catch { }
    if ($exited -or ((Get-Date) - $c.started).TotalSeconds -gt 210) {
        $c.state = 'failed'
        $c.message = '没有取得完整背包。请先退出到游戏登录界面，启动读取后再点击进入游戏。也可使用 Reliquary 官方程序手动导出 JSON。日志保存在 captures 文件夹。'
        return Json @{state='failed';message=$c.message}
    }
    return Json @{state='running';message=$c.message}
}

Write-Output ('RELIC_URL=' + $origin + '/')
if (-not $NoBrowser) { Start-Process ($origin + '/') }
try {
    while (-not $stopRequested) {
        if (-not $listener.Pending()) {
            if (((Get-Date) - $lastRequest).TotalHours -gt 4) { break }
            Start-Sleep -Milliseconds 70
            continue
        }
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 4000
        $client.SendTimeout = 10000
        $stream = $client.GetStream()
        try {
            $request=Read-LocalRequest $stream
            $method=$request.method;$route=$request.route;$headers=$request.headers
            $lastRequest = Get-Date
            if ($headers['host'] -ne ('127.0.0.1:' + $listenPort)) {
                Send-Response $stream 403 (Json @{error='无效主机'})
            } elseif ($route -eq '/' -and $method -eq 'GET') {
                $html = [System.IO.File]::ReadAllText($pagePath, $utf8)
                $config = '<script>globalThis.LOCAL_CONFIG={token:"' + $token + '"};</script>'
                $html = $html.Replace('<script>', $config + '<script>')
                Send-Response $stream 200 $html 'text/html; charset=utf-8'
            } elseif ($route -eq '/favicon.ico') {
                Send-Response $stream 204 ''
            } elseif ($route.StartsWith('/api/')) {
                if ($headers['x-relic-token'] -ne $token -or ($headers['origin'] -and $headers['origin'] -ne $origin)) {
                    Send-Response $stream 403 (Json @{error='请求校验失败，请从本机工具页面重试。'})
                } elseif ($route -eq '/api/capture/start' -and $method -eq 'POST') {
                    try { Send-Response $stream 200 (Json (Start-Capture)) } catch { Send-Response $stream 400 (Json @{error=$_.Exception.Message}) }
                } elseif ($route -eq '/api/capture/status' -and $method -eq 'GET') {
                    Send-Response $stream 200 (Capture-Status)
                } elseif ($route -eq '/api/capture/latest' -and $method -eq 'GET') {
                    $dir=Join-Path $dataBase 'captures'
                    $latest=if(Test-Path -LiteralPath $dir){Get-ChildItem -LiteralPath $dir -Filter '*.json' -File|Sort-Object LastWriteTime -Descending|Select-Object -First 1}else{$null}
                    if($latest -and $latest.Length -le 47185920){$saved=[IO.File]::ReadAllText($latest.FullName,$utf8);Send-Response $stream 200 ('{"state":"saved","data":'+$saved+'}')}
                    else{Send-Response $stream 200 (Json @{state='empty'})}
                } elseif ($route -eq '/api/marker/status' -and $method -eq 'GET') {
                    Send-Response $stream 200 (Json (Get-MarkerStatus))
                } elseif ($route -eq '/api/marker/calibrate' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Start-MarkerWorker 'Calibrate' $null $false))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/marker/start' -and $method -eq 'POST') {
                    try{$body=ConvertFrom-Json $request.body;Validate-MarkerPlan $body.plan|Out-Null;Send-Response $stream 200 (Json (Start-MarkerWorker 'Run' $body.plan ([bool]$body.previewOnly)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/marker/stop' -and $method -eq 'POST') {
                    if($script:markerJob){[IO.File]::WriteAllText((Join-Path $script:markerJob.directory 'stop'),'stop',$utf8)}
                    Send-Response $stream 200 (Json @{state='stopping';message='已请求停止，脚本会在下一次输入前停下。'})
                } elseif ($route -eq '/api/health' -and $method -eq 'GET') {
                    Send-Response $stream 200 (Json @{state='ok';version='1.3';capture='Reliquary v0.20.0';scoring='Fribbels';marker='Chinese Windows OCR'})
                } elseif ($route -eq '/api/exit' -and $method -eq 'POST') {
                    Send-Response $stream 200 (Json @{state='closing'})
                    if($script:markerJob){[IO.File]::WriteAllText((Join-Path $script:markerJob.directory 'stop'),'stop',$utf8)}
                    $stopRequested = $true
                } else { Send-Response $stream 404 (Json @{error='接口不存在'}) }
            } else { Send-Response $stream 404 (Json @{error='页面不存在'}) }
        } catch {
            try { Send-Response $stream 500 (Json @{error='本机服务处理失败：' + $_.Exception.Message}) } catch { }
        } finally {
            $stream.Dispose()
            $client.Close()
        }
    }
} finally { $listener.Stop() }
