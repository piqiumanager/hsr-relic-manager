using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace RelicDesktop {
 public static class Entry {
    public static int Run(string app,string root,string[] args) {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        using(var form=new DeskForm(app,root,args)){Application.Run(form);return form.ExitCode;}
    }
 }
 internal sealed class DeskForm:Form {
    readonly string app,root,report,screenshot;readonly bool testing;
    WebView2 view;Label loading;Process server;string origin;bool closing,closed;public int ExitCode=0;
    static string Value(string[] args,string key){int i=Array.IndexOf(args,key);return i>=0&&i+1<args.Length?args[i+1]:null;}
    public DeskForm(string appPath,string rootPath,string[] args){
        app=appPath;root=rootPath;testing=args.Contains("--self-test");report=Value(args,"--report");screenshot=Value(args,"--screenshot");
        Text="绷铁遗器一键分解 · v1.3";StartPosition=FormStartPosition.CenterScreen;ClientSize=new Size(1100,900);MinimumSize=new Size(780,620);BackColor=Color.FromArgb(245,247,253);
        string icon=Path.Combine(app,"app.ico");if(File.Exists(icon))Icon=new Icon(icon);
        loading=new Label{Dock=DockStyle.Fill,Text="正在启动遗器整理助手…",TextAlign=ContentAlignment.MiddleCenter,Font=new Font("Microsoft YaHei UI",13)};Controls.Add(loading);
        if(testing){ShowInTaskbar=false;Location=new Point(-10000,-10000);StartPosition=FormStartPosition.Manual;}
        Trace("Constructed desktop form");
        Shown+=async(s,e)=>await Start();FormClosing+=OnClosing;
    }
    async Task Start(){
        try {
            Trace("Starting desktop services");
            string version;
            try { version=CoreWebView2Environment.GetAvailableBrowserVersionString(); }
            catch(WebView2RuntimeNotFoundException) {
                if(testing)throw;
                loading.Text="需要安装 Microsoft Edge WebView2 Runtime。\n安装后重新打开本工具。";
                var button=new Button{Text="打开微软官方下载页",AutoSize=true,Anchor=AnchorStyles.None,Location=new Point(510,470)};
                button.Click+=(s,e)=>OpenExternal("https://developer.microsoft.com/microsoft-edge/webview2/");Controls.Add(button);button.BringToFront();return;
            }
            Trace("Found WebView2 "+version);
            Directory.CreateDirectory(Path.Combine(root,"data"));
            var psi=new ProcessStartInfo{FileName=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe"),Arguments="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \""+Path.Combine(app,"server.ps1")+"\" -NoBrowser -DataRoot \""+Path.Combine(root,"data")+"\"",WorkingDirectory=app,UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=true,RedirectStandardError=true};
            server=new Process{StartInfo=psi};server.Start();
            Trace("Started local server PID="+server.Id);
            var urlTask=server.StandardOutput.ReadLineAsync();
            if(await Task.WhenAny(urlTask,Task.Delay(20000))!=urlTask)throw new TimeoutException("本机服务启动超时。");
            string line=await urlTask;
            if(line==null||!line.StartsWith("RELIC_URL=http://127.0.0.1:")) { string error=server.HasExited?await server.StandardError.ReadToEndAsync():"";throw new InvalidOperationException("本机服务未能启动。"+error); }
            origin=line.Substring("RELIC_URL=".Length).TrimEnd('/');
            Trace("Local server ready");
            view=new WebView2{Dock=DockStyle.Fill};Controls.Add(view);
            var env=await CoreWebView2Environment.CreateAsync(null,Path.Combine(root,"webview"));
            // All app pages are served by our session-authenticated loopback service.
            await view.EnsureCoreWebView2Async(env);
            Trace("Created embedded WebView2");
            view.CoreWebView2.Settings.AreDevToolsEnabled=false;Trace("Disabled devtools");
            view.CoreWebView2.Settings.AreDefaultContextMenusEnabled=false;Trace("Configured context menu");
            view.CoreWebView2.Settings.IsStatusBarEnabled=false;Trace("Configured status bar");
            view.CoreWebView2.PermissionRequested+=(s,e)=>e.State=CoreWebView2PermissionState.Deny;
            view.CoreWebView2.NavigationStarting+=(s,e)=>{
                Trace("Navigation started");
                Uri u; if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out u)||u.GetLeftPart(UriPartial.Authority)!=origin){e.Cancel=true;if(Uri.TryCreate(e.Uri,UriKind.Absolute,out u)&&u.Scheme=="https")OpenExternal(e.Uri);}
            };
            view.CoreWebView2.NewWindowRequested+=(s,e)=>{e.Handled=true;OpenExternal(e.Uri);};
            view.CoreWebView2.DownloadStarting+=(s,e)=>{
                using(var dialog=new SaveFileDialog{FileName=Path.GetFileName(e.ResultFilePath),OverwritePrompt=true}){if(dialog.ShowDialog(this)==DialogResult.OK)e.ResultFilePath=dialog.FileName;else e.Cancel=true;}
            };
            view.CoreWebView2.NavigationCompleted+=async(s,e)=>{
                Trace("Navigation completed: "+e.IsSuccess);
                if(!e.IsSuccess){Fail(new InvalidOperationException("界面加载失败："+e.WebErrorStatus));return;}
                loading.Hide();view.BringToFront();
                if(testing)await SelfTest(version);
            };
            view.CoreWebView2.Navigate(origin+"/");
            Trace("Navigating to app");
            if(testing){await Task.Delay(30000);if(!closed&&!closing)Fail(new TimeoutException("Desktop navigation/self-test exceeded 30 seconds."));}
        }catch(Exception e){Fail(e);}
    }
    void Trace(string text){if(testing&&report!=null)File.AppendAllText(report,text+"\n");}
    void OpenExternal(string url){
        if(testing)return;Uri u;
        if(!Uri.TryCreate(url,UriKind.Absolute,out u)||u.Scheme!="https")return;
        string[] hosts={"github.com","fribbels.github.io","developer.microsoft.com","learn.microsoft.com","www.nasa.gov"};
        if(!hosts.Contains(u.Host))return;
        try{Process.Start(new ProcessStartInfo(url){UseShellExecute=true});}catch(Exception e){MessageBox.Show(e.Message,"无法打开链接");}
    }
    async Task SelfTest(string version){
        try{
            await view.CoreWebView2.ExecuteScriptAsync("globalThis.__desktopHealth='pending';(async()=>{if(!globalThis.QuickFlow||!globalThis.RelicDesk||!globalThis.LOCAL_CONFIG)throw Error('UI globals missing');const r=await fetch('/api/health',{headers:{'X-Relic-Token':LOCAL_CONFIG.token}});const h=await r.json();if(h.version!=='1.3')throw Error('health');globalThis.__desktopHealth='ok';document.getElementById('demoBtn').click();})().catch(e=>globalThis.__desktopHealth=e.message)");
            // ExecuteScriptAsync doesn't await JavaScript promises; poll a concrete result.
            string demo="";
            for(int i=0;i<100;i++){await Task.Delay(150);demo=await view.CoreWebView2.ExecuteScriptAsync("JSON.stringify({ready:!!RelicDesk.result,count:RelicDesk.result?.rows.length,quick:!!QuickFlow,token:!!LOCAL_CONFIG.token,health:globalThis.__desktopHealth})");if(demo.Contains("112"))break;}
            if(!demo.Contains("112")||!demo.Contains("ok"))throw new Exception("示例评分或桌面界面自检失败："+demo);
            if(screenshot!=null){Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(screenshot)));using(var file=File.Create(screenshot))await view.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png,file);}
            if(report!=null)File.WriteAllText(report,"PASS\nWebView2="+version+"\nDemo="+demo+"\nBundledReliquary="+File.Exists(Path.Combine(app,"tools","reliquary-archiver-pktmon-x64.exe"))+"\nNo game capture or mouse input was invoked.\n");
            Close();
        }catch(Exception e){Fail(e);}
    }
    void Fail(Exception e){
        ExitCode=1;if(testing){if(report!=null)File.WriteAllText(report,"FAIL\n"+e);Close();}
        else{loading.Text="启动失败："+e.Message+"\n请重新打开，或到 GitHub 提交此信息。";loading.BringToFront();}
    }
    async void OnClosing(object sender,FormClosingEventArgs e){
        if(closed)return;e.Cancel=true;if(closing)return;closing=true;
        try{
            if(view!=null&&view.CoreWebView2!=null)await view.CoreWebView2.ExecuteScriptAsync("fetch('/api/exit',{method:'POST',headers:{'X-Relic-Token':LOCAL_CONFIG.token}}).catch(()=>{});");
            if(server!=null&&!server.HasExited){await Task.Delay(900);if(!server.HasExited)server.Kill();}
        }catch{}finally{
            string runs=Path.Combine(root,"data","marker-runs");
            if(Directory.Exists(runs))foreach(var dir in Directory.GetDirectories(runs))try{File.WriteAllText(Path.Combine(dir,"stop"),"desktop closed");}catch{}
            if(view!=null)view.Dispose();if(server!=null)server.Dispose();closed=true;Close();
        }
    }
 }
}
