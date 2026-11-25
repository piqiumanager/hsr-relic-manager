using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("星铁遗器整理助手")]
[assembly: AssemblyVersion("1.3.0.0")]
[assembly: AssemblyFileVersion("1.3.0.0")]
internal static class Launcher {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern bool SetDllDirectory(string directory);
    static string Hash(byte[] bytes) { using (var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant(); }
    static string Value(string[] args,string key) { int i=Array.IndexOf(args,key); return i>=0 && i+1<args.Length ? args[i+1] : null; }
    [STAThread] static int Main(string[] args) {
        bool selfTest=args.Contains("--self-test");
        string root=Value(args,"--test-root") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"HSRRelicManager");
        Mutex mutex=null;
        try {
            if(selfTest&&Value(args,"--report")!=null)File.WriteAllText(Value(args,"--report"),"Starting extraction\n");
            if(!selfTest) { bool created;mutex=new Mutex(true,"Local\\HSRRelicManager.Desktop",out created);if(!created) { MessageBox.Show("工具已打开，请在任务栏切换到“星铁遗器整理助手”。","星铁遗器整理助手");return 0;} }
            byte[] payload;
            using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip")) {
                if(stream==null)throw new InvalidDataException("内置文件缺失，请重新下载 EXE。");
                using(var memory=new MemoryStream()){stream.CopyTo(memory);payload=memory.ToArray();}
            }
            string app=Path.Combine(root,"app","1.3.0-"+Hash(payload).Substring(0,12));
            Directory.CreateDirectory(app);
            string prefix=Path.GetFullPath(app)+Path.DirectorySeparatorChar;
            using(var zip=new ZipArchive(new MemoryStream(payload),ZipArchiveMode.Read)) {
                foreach(var entry in zip.Entries) {
                    if(entry.FullName.EndsWith("/"))continue;
                    string target=Path.GetFullPath(Path.Combine(app,entry.FullName.Replace('/',Path.DirectorySeparatorChar)));
                    if(!target.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("内置文件路径无效。");
                    using(var stream=entry.Open())using(var memory=new MemoryStream()) {
                        stream.CopyTo(memory);byte[] bytes=memory.ToArray();
                        if(File.Exists(target)&&Hash(File.ReadAllBytes(target))==Hash(bytes))continue;
                        Directory.CreateDirectory(Path.GetDirectoryName(target));
                        File.WriteAllBytes(target+".new",bytes);
                        if(File.Exists(target))File.Delete(target);
                        File.Move(target+".new",target);
                    }
                }
            }
            SetDllDirectory(app);
            if(selfTest&&Value(args,"--report")!=null)File.AppendAllText(Value(args,"--report"),"Extracted payload\n");
            AppDomain.CurrentDomain.AssemblyResolve+=(sender,e)=>{
                string dll=Path.Combine(app,new AssemblyName(e.Name).Name+".dll");
                return File.Exists(dll)?Assembly.LoadFrom(dll):null;
            };
            var host=Assembly.LoadFrom(Path.Combine(app,"DesktopHost.dll"));
            return (int)host.GetType("RelicDesktop.Entry").GetMethod("Run").Invoke(null,new object[]{app,root,args});
        } catch(Exception e) {
            var error=e is TargetInvocationException && e.InnerException!=null?e.InnerException:e;
            string message=error.ToString();
            if(selfTest) { string report=Value(args,"--report");if(report!=null){Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(report)));File.WriteAllText(report,message);} }
            else MessageBox.Show("启动失败："+error.Message+"\n\n请重新下载完整 EXE；问题仍存在时，将此信息提交到 GitHub。","星铁遗器整理助手",MessageBoxButtons.OK,MessageBoxIcon.Error);
            return 1;
        } finally { if(mutex!=null)mutex.Dispose(); }
    }
}
