param([switch]$NoBrowser, [int]$Port = 0, [string]$DataRoot = '',[ValidateRange(0,5)][int]$ValidationMarks=0)
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
. (Join-Path $base 'upgrade-core.ps1')
. (Join-Path $base 'marker-core.ps1')
. (Join-Path $base 'live-core.ps1')
. (Join-Path $base 'live-server.ps1')
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
function ConvertTo-Appearance($Body){
    if($null-eq$Body.opacity){throw '清晰度无效。'};$opacity=[double]$Body.opacity
    if([double]::IsNaN($opacity)-or[double]::IsInfinity($opacity)-or$opacity-lt .25-or$opacity-gt 1){throw '清晰度应在 25% 到 100% 之间。'}
    $id=[string]$Body.lastBackground;$credits=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/backgrounds/credits.json'),$utf8))
    if($id-and$id-notin @($credits.images|ForEach-Object{$_.id})){throw '角色图片不存在。'}
    return @{opacity=$opacity;lastBackground=$id}
}
function Get-Appearance {
    $file=Join-Path $dataBase 'appearance.json'
    if(Test-Path -LiteralPath $file){try{return ConvertTo-Appearance (ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8)))}catch{}}
    return @{opacity=.82;lastBackground=''}
}
function Save-Appearance($Body){
    $value=ConvertTo-Appearance $Body;[IO.Directory]::CreateDirectory($dataBase)|Out-Null
    $file=Join-Path $dataBase 'appearance.json';$temporary=$file+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temporary,(Json $value),$utf8);Move-Item -LiteralPath $temporary -Destination $file -Force
    return $value
}
function Send-OcrAsset($stream,[string]$Route){
    $name=$Route.Substring(5)
    if($name-notin @('tesseract.min.js','worker.min.js','tesseract-core-lstm.js','tesseract-core-lstm.wasm','eng.traineddata')){Send-Response $stream 404 (Json @{error='资源不存在'});return}
    $bytes=[IO.File]::ReadAllBytes((Join-Path $base ('source/ocr/'+$name)));$mime=if($name.EndsWith('.js')){'application/javascript'}elseif($name.EndsWith('.wasm')){'application/wasm'}else{'application/octet-stream'}
    $header=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nCache-Control: private, max-age=86400`r`nX-Content-Type-Options: nosniff`r`n`r`n");$stream.Write($header,0,$header.Length);$stream.Write($bytes,0,$bytes.Length);$stream.Flush()
}

function Send-BackgroundAsset($stream,[string]$Route){
    $name=$Route.Substring('/source/backgrounds/'.Length)
    if($name-notmatch'^[a-z0-9-]+\.webp$'){Send-Response $stream 404 (Json @{error='资源不存在'});return}
    $credits=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/backgrounds/credits.json'),$utf8))
    if($name-notin @($credits.images|ForEach-Object{$_.id+'.webp'})){Send-Response $stream 404 (Json @{error='资源不存在'});return}
    $bytes=[IO.File]::ReadAllBytes((Join-Path $base ('source/backgrounds/'+$name)))
    $header=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: image/webp`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`nCache-Control: private, max-age=86400`r`nX-Content-Type-Options: nosniff`r`n`r`n");$stream.Write($header,0,$header.Length);$stream.Write($bytes,0,$bytes.Length);$stream.Flush()
}
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
    $ready=$true
    if(-not$script:markerJob){return @{state='idle';calibrated=$ready;message='尚未启动游戏内标记。'}}
    $file=Join-Path $script:markerJob.directory 'status.json';$state=$null;$exited=$false
    try{$exited=$script:markerJob.process.HasExited}catch{}
    if(Test-Path -LiteralPath $file){try{$state=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8))}catch{}}
    if($state){
      if($state.state-in @('starting','calibrating','running','awaitingScore')-and$exited){
        $state|Add-Member -NotePropertyName state -NotePropertyValue 'failed' -Force
        $state.PSObject.Properties.Remove('request');$detail='';$log=Join-Path $script:markerJob.directory 'failure.log'
        try{if(Test-Path -LiteralPath $log){$detail=([IO.File]::ReadAllText($log,$utf8)-split'\r?\n')[0]}}catch{}
        $message=if($detail){'执行中断：'+$detail}else{'执行进程已退出，已确认标记 '+[int]$state.marked+' 件。请查看本次记录。'}
        $state|Add-Member -NotePropertyName message -NotePropertyValue $message -Force
      }
      if($script:markerJob.kind-eq'upgrade'-and([int]$state.confirmedSteps-gt 0-or[int]$state.marked-gt 0)-and$script:capture){$script:capture.invalidated=$true}
      $state|Add-Member -NotePropertyName calibrated -NotePropertyValue $ready -Force
      $state|Add-Member -NotePropertyName kind -NotePropertyValue $script:markerJob.kind -Force
      return $state
    }
    if($exited){return @{state='failed';kind=$script:markerJob.kind;calibrated=$ready;message='执行进程已退出，尚未生成有效状态记录。请查看本次任务记录。'}}
    return @{state='starting';kind=$script:markerJob.kind;calibrated=$ready;message='正在等待管理员授权并准备本机识别…'}
}

function Assert-MarkerIdle {
    $state=Get-MarkerStatus
    if($state.state -in @('running','starting','calibrating','awaitingScore')){throw '标记或校准正在进行，请先停止当前任务。'}
}
function Start-GameWorker([string]$Arguments){
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){return Start-Process -FilePath 'powershell.exe' -ArgumentList $Arguments -WindowStyle Hidden -PassThru}
    return Start-Process -FilePath 'powershell.exe' -ArgumentList $Arguments -Verb RunAs -WindowStyle Hidden -PassThru
}

function Start-MarkerWorker([string]$Mode,$Plan,[bool]$Preview) {
    if($Mode -notin @('Run','Upgrade')){throw '本版本自动定位，不再需要手动校准。'}
    Assert-MarkerIdle
    $jobId=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $dir=Join-Path (Join-Path $dataBase 'marker-runs') $jobId
    [IO.Directory]::CreateDirectory($dir)|Out-Null
    $worker=if($Mode -eq 'Upgrade'){'upgrade.ps1'}else{'marker.ps1'}
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $base $worker)+'" -Mode '+$Mode+' -JobDirectory "'+$dir+'" -DataRoot "'+$dataBase+'"'
    if($Mode -in @('Run','Upgrade')){
        $planFile=Join-Path $dir 'plan.json'
        [IO.File]::WriteAllText($planFile,(ConvertTo-Json $Plan -Depth 40 -Compress),$utf8)
        $args+=' -PlanPath "'+$planFile+'"';if($Preview){$args+=' -PreviewOnly'}
    }
    $process=Start-GameWorker $args
    $script:markerJob=@{id=$jobId;directory=$dir;process=$process;started=Get-Date;kind=$(if($Mode -eq 'Upgrade'){'upgrade'}else{'marker'})}
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
    if($script:capture -and $script:capture.invalidated){throw '遗器已变化，请重新读取背包。'}
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

function Validate-UpgradePlan($Plan){
    if($Plan.operation -ne 'upgrade' -or $Plan.policy.step -ne 3 -or $Plan.policy.threshold -ne 80 -or $Plan.policy.maxLevel -ne 15 -or $Plan.policy.maxRelicMaterialRarity -ne 4 -or $Plan.policy.allowLockedMaterials -ne $false -or $Plan.policy.allowEquippedMaterials -ne $false -or $Plan.allowSalvage -ne $false){throw '强化规则不符合已设定的 +3 / 80 分 / 四星材料规则。'}
    Validate-MarkerPlan $Plan|Out-Null
    $data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source\data.json'),$utf8))
    if(@($Plan.targetIds).Count -lt 1 -or @($Plan.targetIds).Count -gt 120){throw '强化评分角色列表无效。'}
    foreach($id in $Plan.targetIds){if(-not $data.profiles.([string]$id)){throw '强化评分角色未收录。'}}
    foreach($c in $Plan.candidates){if($c.enhance -ge 15 -or $c.enhance%3 -ne 0 -or @($c.initialScores).Count -ne $c.count){throw '强化候选等级或初始评分不完整。'}}
    return $true
}
function Accept-UpgradeDecision($Decision){
    if(-not $script:markerJob -or $script:markerJob.kind -ne 'upgrade'){throw '没有运行中的强化任务。'}
    $requestFile=Join-Path $script:markerJob.directory 'request.json'
    if(-not(Test-Path -LiteralPath $requestFile)){throw '当前没有待回应的强化评分。'}
    $request=ConvertFrom-Json ([IO.File]::ReadAllText($requestFile,$utf8))
    if($request.requestId -notmatch '^[a-f0-9]{32}$' -or $Decision.requestId -ne $request.requestId){throw '强化评分回应已过期。'}
    Assert-UpgradeDecision $request $Decision|Out-Null
    $file=Join-Path $script:markerJob.directory ('decision-'+$request.requestId+'.json')
    if(-not(Test-Path -LiteralPath $file)){[IO.File]::WriteAllText($file+'.tmp',(Json $Decision),$utf8);Move-Item -LiteralPath ($file+'.tmp') -Destination $file -Force}
    return @{state='accepted';requestId=$request.requestId}
}

function Start-Capture {
    Assert-MarkerIdle
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
                $config = '<script>globalThis.LOCAL_CONFIG={token:"' + $token + '",appearance:'+(Json (Get-Appearance))+'};</script>'
                $html = $html.Replace('<script>', $config + '<script>')
                Send-Response $stream 200 $html 'text/html; charset=utf-8'
            } elseif ($route -eq '/favicon.ico') {
                Send-Response $stream 204 ''
            } elseif ($route.StartsWith('/ocr/') -and $method -eq 'GET') {
                Send-OcrAsset $stream $route
            } elseif ($route.StartsWith('/source/backgrounds/') -and $method -eq 'GET') {
                Send-BackgroundAsset $stream $route
            } elseif ($route.StartsWith('/api/')) {
                if ($headers['x-relic-token'] -ne $token -or ($headers['origin'] -and $headers['origin'] -ne $origin)) {
                    Send-Response $stream 403 (Json @{error='请求校验失败，请从本机工具页面重试。'})
                } elseif ($route -eq '/api/appearance' -and $method -eq 'GET') {
                    Send-Response $stream 200 (Json (Get-Appearance))
                } elseif ($route -eq '/api/appearance' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Save-Appearance (ConvertFrom-Json $request.body)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
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
                } elseif ($route -eq '/api/live/start' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Start-LiveWorker (ConvertFrom-Json $request.body)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.GetBaseException().Message})}
                } elseif ($route -eq '/api/live/decision' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Accept-LiveDecision (ConvertFrom-Json $request.body)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/live/snapshot' -and $method -eq 'GET') {
                    try{Send-Response $stream 200 (Get-LiveSnapshot)}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/marker/calibrate' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Start-MarkerWorker 'Calibrate' $null $false))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/marker/start' -and $method -eq 'POST') {
                    try{$body=ConvertFrom-Json $request.body;Validate-MarkerPlan $body.plan|Out-Null;Send-Response $stream 200 (Json (Start-MarkerWorker 'Run' $body.plan ([bool]$body.previewOnly)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/upgrade/start' -and $method -eq 'POST') {
                    try{$body=ConvertFrom-Json $request.body;Validate-UpgradePlan $body.plan|Out-Null;Send-Response $stream 200 (Json (Start-MarkerWorker 'Upgrade' $body.plan ([bool]$body.previewOnly)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/upgrade/plan' -and $method -eq 'GET') {
                    if($script:markerJob -and $script:markerJob.kind -eq 'upgrade'){Send-Response $stream 200 ([IO.File]::ReadAllText((Join-Path $script:markerJob.directory 'plan.json'),$utf8))}else{Send-Response $stream 404 (Json @{error='没有运行中的强化任务。'})}
                } elseif ($route -eq '/api/upgrade/decision' -and $method -eq 'POST') {
                    try{Send-Response $stream 200 (Json (Accept-UpgradeDecision (ConvertFrom-Json $request.body)))}catch{Send-Response $stream 400 (Json @{error=$_.Exception.Message})}
                } elseif ($route -eq '/api/marker/stop' -and $method -eq 'POST') {
                    if($script:markerJob){[IO.File]::WriteAllText((Join-Path $script:markerJob.directory 'stop'),'stop',$utf8)}
                    Send-Response $stream 200 (Json @{state='stopping';message='已请求停止，脚本会在下一次输入前停下。'})
                } elseif ($route -eq '/api/health' -and $method -eq 'GET') {
                    Send-Response $stream 200 (Json @{state='ok';version='1.5.5';capture='Reliquary v0.20.0';scoring='Fribbels';marker='Chinese Windows OCR'})
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
