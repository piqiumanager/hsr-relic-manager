// Purpose-limited native input: only a selected StarRail client, grid clicks,
// fixed inventory controls, B/A/D/S navigation, and scrolling. No salvage action.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public sealed class RelicWindow {
  public IntPtr Handle; public int X,Y,Width,Height; public int ProcessId;
}
public static class RelicNative {
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int L,T,R,B; }
  [StructLayout(LayoutKind.Sequential)] struct POINT { public int X,Y; }
  [StructLayout(LayoutKind.Sequential)] struct MI { public int dx,dy; public uint mouseData,dwFlags,time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] struct KI { public ushort key,scan; public uint flags,time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit)] struct IU { [FieldOffset(0)] public MI mouse; [FieldOffset(0)] public KI keyboard; }
  [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public IU u; }
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out RECT r);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h,ref POINT p);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int command);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint from,uint to,bool attach);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint n,INPUT[] input,int size);
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int key);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public static bool StopPressed() { return (GetAsyncKeyState(0x77)&0x8000)!=0; }
  public static RelicWindow FindGame() {
    var games=new List<Process>();
    foreach(var p in Process.GetProcessesByName("StarRail")) if(p.MainWindowHandle!=IntPtr.Zero)games.Add(p);
    if(games.Count!=1)throw new Exception("请只打开一个 Windows 本地星穹铁道客户端，并进入遗器背包。");
    var process=games[0];var h=process.MainWindowHandle;
    if(IsIconic(h))throw new Exception("游戏已最小化，请打开遗器背包后重试。");
    RECT r;POINT pt=new POINT();
    if(!GetClientRect(h,out r)||!ClientToScreen(h,ref pt))throw new Exception("无法读取游戏窗口位置。");
    if(r.R<960||r.B<540)throw new Exception("请使用至少 960×540 的游戏窗口。");
    return new RelicWindow {Handle=h,X=pt.X,Y=pt.Y,Width=r.R,Height=r.B,ProcessId=process.Id};
  }
  public static void Activate(RelicWindow w) {
    ShowWindow(w.Handle,9);SetForegroundWindow(w.Handle);Thread.Sleep(500);
    if(GetForegroundWindow()!=w.Handle){uint current=GetCurrentThreadId(),foreground=GetWindowThreadProcessId(GetForegroundWindow(),IntPtr.Zero);bool attached=false;
      try{if(foreground!=current)attached=AttachThreadInput(current,foreground,true);SetForegroundWindow(w.Handle);}finally{if(attached)AttachThreadInput(current,foreground,false);}Thread.Sleep(500);
    }
    Guard(w);
  }
  public static void TapNavigation(RelicWindow w,string key) {
    Guard(w);ushort vk;
    switch(key){case "B":vk=0x42;break;case "A":vk=0x41;break;case "D":vk=0x44;break;case "S":vk=0x53;break;case "Escape":vk=0x1B;break;default:throw new Exception("不允许的导航按键。");}
    var inputs=new INPUT[2];inputs[0].type=inputs[1].type=1;inputs[0].u.keyboard.key=inputs[1].u.keyboard.key=vk;inputs[1].u.keyboard.flags=2;
    if(SendInput(2,inputs,Marshal.SizeOf(typeof(INPUT)))!=2){var up=new INPUT[1];up[0]=inputs[1];SendInput(1,up,Marshal.SizeOf(typeof(INPUT)));throw new Exception("导航按键未完整发送，已停止。");}
  }
  public static bool ClearlyUnlocked(Bitmap b) {
    int white=0,dark=0,gold=0,total=b.Width*b.Height;
    for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var p=b.GetPixel(x,y);if(p.R>220&&p.G>220&&p.B>220)white++;if(p.R<80&&p.G<80&&p.B<80)dark++;if(p.R>145&&p.G>105&&p.B<120)gold++;}
    return (double)white/total>0.3&&(double)dark/total>0.02&&(double)gold/total<0.1;
  }
  public static void Guard(RelicWindow w) {
    if(StopPressed())throw new OperationCanceledException("已按 F8 停止。");
    var now=FindGame();
    if(now.Handle!=w.Handle||now.Width!=w.Width||now.Height!=w.Height||now.X!=w.X||now.Y!=w.Y)throw new Exception("游戏窗口或分辨率发生变化，已停止。");
    if(GetForegroundWindow()!=w.Handle)throw new Exception("游戏失去前台焦点，已停止。请回到背包后重新运行。");
  }
  public static Bitmap Capture(RelicWindow w) {
    Guard(w);var b=new Bitmap(w.Width,w.Height,PixelFormat.Format32bppArgb);
    try {using(var g=Graphics.FromImage(b))g.CopyFromScreen(w.X,w.Y,0,0,b.Size,CopyPixelOperation.SourceCopy);return b;}catch{b.Dispose();throw;}
  }
  static void SendMouse(RelicWindow w,int x,int y,uint flags,uint data) {
    Guard(w);if(x<0||y<0||x>=w.Width||y>=w.Height)throw new Exception("点击位置超出游戏窗口。");
    SetCursorPos(w.X+x,w.Y+y);Thread.Sleep(35);Guard(w);
    var a=new INPUT[1];a[0].type=0;a[0].u.mouse.dwFlags=flags;a[0].u.mouse.mouseData=data;
    if(SendInput(1,a,Marshal.SizeOf(typeof(INPUT)))!=1)throw new Exception("游戏没有接受鼠标操作，请以管理员权限启动标记。");
  }
  static void ClickAt(RelicWindow w,int x,int y) {
    Guard(w);if(x<0||y<0||x>=w.Width||y>=w.Height)throw new Exception("点击位置超出游戏窗口。");
    SetCursorPos(w.X+x,w.Y+y);Thread.Sleep(35);Guard(w);
    var a=new INPUT[2];a[0].u.mouse.dwFlags=2;a[1].u.mouse.dwFlags=4;
    uint sent=SendInput(2,a,Marshal.SizeOf(typeof(INPUT)));
    if(sent!=2){var up=new INPUT[1];up[0].u.mouse.dwFlags=4;SendInput(1,up,Marshal.SizeOf(typeof(INPUT)));throw new Exception("鼠标点击未完整执行，已停止。");}
  }
  public static void ClickGrid(RelicWindow w,int x,int y) { ClickAt(w,x,y); }
  public static void ClickDiscard(RelicWindow w,int x,int y) { ClickAt(w,x,y); }
  public static void ClickVerifiedControl(RelicWindow w,int x,int y) { ClickAt(w,x,y); }
  public static void HoverControl(RelicWindow w,int x,int y) { Guard(w);if(x<0||y<0||x>=w.Width||y>=w.Height)throw new Exception("悬停位置越界。");SetCursorPos(w.X+x,w.Y+y);Thread.Sleep(400);Guard(w); }
  static bool WhitePixel(Color p){return p.R>185&&p.G>185&&p.B>185&&Math.Abs(p.R-p.B)<45;}
  public static int CountEmptyMaterialSlots(Bitmap b){
    var centers=new List<Point>();
    for(int y=15;y<b.Height-15;y++)for(int x=15;x<b.Width-15;x++){
      if(!WhitePixel(b.GetPixel(x,y)))continue;
      int l=x,r=x,t=y,d=y;
      while(l>0&&x-l<45&&WhitePixel(b.GetPixel(l-1,y)))l--;while(r<b.Width-1&&r-x<45&&WhitePixel(b.GetPixel(r+1,y)))r++;
      if(r-l<12||r-l>44)continue;
      while(t>0&&y-t<45&&WhitePixel(b.GetPixel(x,t-1)))t--;while(d<b.Height-1&&d-y<45&&WhitePixel(b.GetPixel(x,d+1)))d++;
      if(d-t<12||d-t>44||Math.Abs((l+r)/2-x)>4||Math.Abs((t+d)/2-y)>4)continue;
      var p=new Point((l+r)/2,(t+d)/2);if(centers.Exists(q=>Math.Abs(q.X-p.X)<25&&Math.Abs(q.Y-p.Y)<25))continue;centers.Add(p);
    }
    if(centers.Count!=8)return centers.Count;
    centers.Sort((a,c)=>a.Y.CompareTo(c.Y));
    for(int i=0;i<4;i++)if(Math.Abs(centers[i].Y-centers[0].Y)>18||Math.Abs(centers[i+4].Y-centers[4].Y)>18)return -1;
    if(centers[4].Y-centers[0].Y<50)return -1;return 8;
  }
  public static void ScrollDown(RelicWindow w,int x,int y) { SendMouse(w,x,y,0x0800,unchecked((uint)-120)); }
  public static void ScrollToTop(RelicWindow w,int x,int y) { for(int i=0;i<12;i++){SendMouse(w,x,y,0x0800,12000);Thread.Sleep(20);} }
  public static Bitmap Crop(Bitmap b,int x,int y,int width,int height) {
    if(x<0||y<0||width<4||height<4||x+width>b.Width||y+height>b.Height)throw new Exception("校准区域超出游戏画面。");
    return b.Clone(new Rectangle(x,y,width,height),PixelFormat.Format32bppArgb);
  }
  public static double Difference(Bitmap a,Bitmap b) {
    using(var aa=new Bitmap(a,new Size(48,32)))using(var bb=new Bitmap(b,new Size(48,32))){
      double sum=0;for(int y=0;y<32;y++)for(int x=0;x<48;x++){var p=aa.GetPixel(x,y);var q=bb.GetPixel(x,y);sum+=Math.Abs(p.R-q.R)+Math.Abs(p.G-q.G)+Math.Abs(p.B-q.B);}
      return sum/(48*32*3);
    }
  }
  public static int RedPixels(Bitmap b) {
    int count=0;for(int y=0;y<b.Height;y++)for(int x=0;x<b.Width;x++){var p=b.GetPixel(x,y);if(p.R>125&&p.R>p.G*1.32&&p.R>p.B*1.25)count++;}return count;
  }
  public static string ImageHash(Bitmap b) {
    using(var small=new Bitmap(b,new Size(32,20))){var text=new System.Text.StringBuilder();for(int y=0;y<20;y++)for(int x=0;x<32;x++){var p=small.GetPixel(x,y);text.Append((char)('A'+(p.R+p.G+p.B)/48));}return text.ToString();}
  }
}
