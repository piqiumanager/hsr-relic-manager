// Purpose-limited native input: only a selected StarRail client, grid clicks,
// one calibrated discard control, and scrolling. No keyboard or salvage action.
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
  [StructLayout(LayoutKind.Explicit)] struct IU { [FieldOffset(0)] public MI mouse; }
  [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public IU u; }
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out RECT r);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h,ref POINT p);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
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
  public static void Activate(RelicWindow w) { SetForegroundWindow(w.Handle); Thread.Sleep(450); }
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
  public static void ScrollDown(RelicWindow w,int x,int y) { SendMouse(w,x,y,0x0800,unchecked((uint)-120)); }
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
  // Calibration is user-driven on a still screenshot. Its clicks never reach the game.
  public static int[][] Calibrate(Bitmap screenshot,string[] steps,string stopPath) {
    var points=new List<int[]>();
    using(var form=new Form())using(var image=(Bitmap)screenshot.Clone()){
      form.Text="遗器弃置位置校准 · Esc 取消";form.StartPosition=FormStartPosition.CenterScreen;form.TopMost=true;form.KeyPreview=true;
      int screenWidth=Screen.PrimaryScreen.WorkingArea.Width-80,screenHeight=Screen.PrimaryScreen.WorkingArea.Height-110;
      double scale=Math.Min(1.0,Math.Min((double)screenWidth/image.Width,(double)(screenHeight-90)/image.Height));
      int width=(int)(image.Width*scale),height=(int)(image.Height*scale);
      form.ClientSize=new Size(width,height+90);form.FormBorderStyle=FormBorderStyle.FixedDialog;form.MaximizeBox=false;form.MinimizeBox=false;
      var heading=new Label {Dock=DockStyle.Top,Height=55,BackColor=Color.FromArgb(32,38,60),ForeColor=Color.White,Font=new Font("Microsoft YaHei UI",11),Padding=new Padding(12,10,8,5)};
      var picture=new PictureBox {Top=55,Left=0,Width=width,Height=height,Image=image,SizeMode=PictureBoxSizeMode.StretchImage};
      var help=new Label {Top=height+55,Height=35,Left=0,Width=width,Text="依次单击提示位置。点错可按退格撤销，Esc 取消。截图上的点击不会操作游戏。",Padding=new Padding(10,7,0,0),ForeColor=Color.DimGray};
      Action update=()=>{heading.Text=String.Format("第 {0}/{1} 步：{2}",Math.Min(points.Count+1,steps.Length),steps.Length,steps[Math.Min(points.Count,steps.Length-1)]);picture.Invalidate();};
      picture.Paint+=(sender,args)=>{using(var pen=new Pen(Color.FromArgb(90,220,190),2)){for(int i=0;i<points.Count;i++){float x=(float)(points[i][0]*scale),y=(float)(points[i][1]*scale);args.Graphics.DrawEllipse(pen,x-5,y-5,10,10);args.Graphics.DrawString((i+1).ToString(),SystemFonts.DefaultFont,Brushes.White,x+6,y-8);}}};
      picture.MouseClick+=(sender,args)=>{points.Add(new int[]{(int)Math.Round(args.X/scale),(int)Math.Round(args.Y/scale)});if(points.Count==steps.Length){form.DialogResult=DialogResult.OK;form.Close();}else update();};
      form.KeyDown+=(sender,args)=>{if(args.KeyCode==Keys.Escape){form.DialogResult=DialogResult.Cancel;form.Close();}if(args.KeyCode==Keys.Back&&points.Count>0){points.RemoveAt(points.Count-1);update();}};
      form.Controls.Add(picture);form.Controls.Add(heading);form.Controls.Add(help);update();
      using(var timer=new System.Windows.Forms.Timer()){
        timer.Interval=180;timer.Tick+=(sender,args)=>{if(StopPressed()||System.IO.File.Exists(stopPath)){form.DialogResult=DialogResult.Cancel;form.Close();}};timer.Start();
        if(form.ShowDialog()!=DialogResult.OK)throw new OperationCanceledException("已取消位置校准。");
      }
    }
    return points.ToArray();
  }
}
