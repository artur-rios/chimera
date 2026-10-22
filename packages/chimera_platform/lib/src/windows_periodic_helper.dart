/// Fixed local helper. Console APIs are deliberately scoped to the console
/// attached through our suspended, job-contained cmd.exe child. No SendKeys,
/// SendInput, clipboard, shell interpolation, or external input is used.
const windowsPeriodicHelper = r'''
$ErrorActionPreference = 'Stop'
$inputStream = [Console]::In
$outputStream = [Console]::Out
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public sealed class ChimeraConsole : IDisposable {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
 struct STARTUPINFO {
  public int cb; public string reserved, desktop, title;
  public int x,y,xSize,ySize,xChars,yChars,fill,flags;
  public short show, reservedSize; public IntPtr reservedPtr,input,output,error;
 }
 [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr process,thread; public uint id,threadId; }
 [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMIT {
  public long processTime,jobTime; public uint flags; public UIntPtr min,max; public uint active; public UIntPtr affinity; public uint priority,scheduling;
 }
 [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong readOps,writeOps,otherOps,readBytes,writeBytes,otherBytes; }
 [StructLayout(LayoutKind.Sequential)] struct EXTENDED_LIMIT { public BASIC_LIMIT basic; public IO_COUNTERS io; public UIntPtr processMemory,jobMemory,peakProcess,peakJob; }
 [StructLayout(LayoutKind.Explicit, Size=20)] struct INPUT_RECORD {
  [FieldOffset(0)] public short type;
  [FieldOffset(4)] public int down;
  [FieldOffset(8)] public short repeat;
  [FieldOffset(10)] public short key;
  [FieldOffset(12)] public short scan;
  [FieldOffset(14)] public char character;
  [FieldOffset(16)] public int control;
 }
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcess(string app, System.Text.StringBuilder command, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO startup, out PROCESS_INFORMATION info);
 [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr process,uint code);
 [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
 [DllImport("kernel32.dll")] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
 [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job,int kind,ref EXTENDED_LIMIT info,uint size);
 [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern bool FreeConsole();
 [DllImport("kernel32.dll")] static extern bool AttachConsole(uint id);
 [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
 [DllImport("kernel32.dll")] static extern uint GetConsoleProcessList([Out] uint[] list,uint count);
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string name,uint access,uint share,IntPtr security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,EntryPoint="WriteConsoleInputW")] static extern bool WriteConsoleInput(SafeFileHandle input,INPUT_RECORD[] events,uint count,out uint written);
 IntPtr job,process,window; uint processId; SafeFileHandle input; bool attached;
 public void Launch() {
  if (process != IntPtr.Zero) throw new InvalidOperationException();
  job=CreateJobObject(IntPtr.Zero,null);
  EXTENDED_LIMIT limit=new EXTENDED_LIMIT(); limit.basic.flags=0x2000;
  if(job==IntPtr.Zero || !SetInformationJobObject(job,9,ref limit,(uint)Marshal.SizeOf(limit))) throw new InvalidOperationException();
  string path=System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"cmd.exe");
  STARTUPINFO startup=new STARTUPINFO(); startup.cb=Marshal.SizeOf(startup);
  PROCESS_INFORMATION info;
  // Suspended creation closes the gap between creation and job assignment.
  if(!CreateProcess(path,new System.Text.StringBuilder("\""+path+"\" /d"),IntPtr.Zero,IntPtr.Zero,false,0x14,IntPtr.Zero,null,ref startup,out info)) throw new InvalidOperationException();
  process=info.process; processId=info.id;
  try {
   if(!AssignProcessToJobObject(job,process)) throw new InvalidOperationException();
   if(ResumeThread(info.thread)==UInt32.MaxValue) throw new InvalidOperationException();
  } finally { CloseHandle(info.thread); }
 }
 bool Alive() { uint code; return process!=IntPtr.Zero && GetExitCodeProcess(process,out code) && code==259; }
 bool OwnConsole() {
  if(!Alive() || !attached || window==IntPtr.Zero || GetConsoleWindow()!=window) return false;
  uint[] ids=new uint[64]; uint count=GetConsoleProcessList(ids,64);
  if(count==0 || count>64) return false;
  for(int i=0;i<count;i++) if(ids[i]==processId) return true;
  return false;
 }
 public void Activate() {
  if(!Alive()) throw new InvalidOperationException();
  FreeConsole();
  if(!AttachConsole(processId)) throw new InvalidOperationException();
  attached=true; window=GetConsoleWindow();
  if(!OwnConsole()) throw new InvalidOperationException();
  input=CreateFile("CONIN$",0x40000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
  if(input.IsInvalid || !SetForegroundWindow(window) || GetForegroundWindow()!=window) throw new InvalidOperationException();
 }
 public string Send(long counter) {
  if(counter<=0 || input==null || input.IsInvalid || !OwnConsole()) return "automation";
  string text="echo Hello World "+counter.ToString(System.Globalization.CultureInfo.InvariantCulture)+"\r";
  INPUT_RECORD[] records=new INPUT_RECORD[text.Length*2];
  for(int i=0;i<text.Length;i++) {
   INPUT_RECORD key=new INPUT_RECORD(); key.type=1; key.down=1; key.repeat=1; key.character=text[i]; key.key=(short)(text[i]=='\r'?13:0);
   records[i*2]=key; key.down=0; records[i*2+1]=key;
  }
  // Focus can race after this check, but the captured console handle cannot
  // redirect these records into any other window's input queue.
  if(!OwnConsole() || GetForegroundWindow()!=window) return "focus_lost";
  uint written;
  if(!WriteConsoleInput(input,records,(uint)records.Length,out written) || written!=records.Length) return "automation";
  return "ok";
 }
 public void Dispose() {
  if(input!=null) { input.Dispose(); input=null; }
  if(attached) { FreeConsole(); attached=false; }
  // Also handles failure before assignment to the kill-on-close job.
  if(process!=IntPtr.Zero) { TerminateProcess(process,0); CloseHandle(process); process=IntPtr.Zero; }
  if(job!=IntPtr.Zero) { CloseHandle(job); job=IntPtr.Zero; }
 }
}
'@
$terminal = New-Object ChimeraConsole
try {
 while ($null -ne ($line = $inputStream.ReadLine())) {
  try {
   $reply = 'automation'
   if ($line -eq 'launch') { $terminal.Launch(); $reply = 'ok' }
   elseif ($line -eq 'activate') { $terminal.Activate(); $reply = 'ok' }
   elseif ($line -match '^send:([1-9][0-9]*)$') { $reply = $terminal.Send([long]::Parse($Matches[1])) }
   $outputStream.WriteLine($reply); $outputStream.Flush()
   if ($reply -ne 'ok') { break }
  } catch { $outputStream.WriteLine('automation'); $outputStream.Flush(); break }
 }
} finally { $terminal.Dispose() }
''';
