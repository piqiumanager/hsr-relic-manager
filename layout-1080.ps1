# Fixed PC keyboard/mouse inventory layout. No user-selected points.
# Proportions adapted from kel-z/HSR-Scanner (GPL-3.0), see licenses/HSR-Scanner.txt.
function Get-RelicLayout1080([int]$Width,[int]$Height){
    if($Width -ne 1920 -or $Height -ne 1080){throw ('当前游戏客户区为 '+$Width+'×'+$Height+'，请在游戏中设为 1920×1080、键鼠模式后重试。')}
    return @{width=1920;height=1080;panel=@{x=1382;y=97;width=480;height=950};substats=@{x=1435;y=433;width=415;height=153};header=@{x=50;y=20;width=360;height=105};first=@(136,217);relicTab=@(826,65);allTab=@(240,135);unlockRect=@{x=1794;y=250;width=38;height=38};discardRect=@{x=1798;y=310;width=34;height=34};discardPoint=@(1815,327);cols=9}
}
function Get-RelicNavigationKey([int]$Index){
    if($Index -lt 0){throw '遗器索引不能小于零。'}
    if(($Index+1)%9 -eq 0){return 'S'}
    if(([int][Math]::Floor($Index/9))%2 -eq 0){return 'D'}
    return 'A'
}
