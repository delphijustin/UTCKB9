program utckb9;
{$RESOURCE UTCKB9Data.res}
uses
  SysUtils,
  windows,
  messages,
  urlmon,shellapi,
  classes;
const TypesSupported:DWord=7;
appname='UTCKB9';
reg_exesize='EXESize';
textfmt='%s, %s';
reg_timeformat='TimeFormat';
var screen:hdc;
hp,hf:THandle;
screenRect:TRECT;
prevPID,exesize,bread,logInstalled,oldexesize,rs:dword;
HType:dword=24;
lastErr:DWORD=0;
UTCParams:tstringlist;
dt:tdatetime;
hkrun,hk,hkapp:HKEY;
I:Integer;
err,UTCData:array[byte]of ansichar;
fn,url,exename:array[0..max_path]of char;
systime:systemtime;
function GetConsoleWindow:hwnd;stdcall;external kernel32;
function IsNT: Boolean;
var
  OS: TOSVersionInfo;
begin
  ZeroMemory(@OS, SizeOf(OS));
  OS.dwOSVersionInfoSize := SizeOf(OS);
  GetVersionEx(OS);
  Result := OS.dwPlatformId = VER_PLATFORM_WIN32_NT;
end;
function readChoice(const text:string;const sKeys:string='YN'):Char;
var choice_exe:shellexecuteinfo;
choice:dword;
begin
zeromemory(@choice_exe,sizeof(choice_exe));
choice_exe.cbSize:=sizeof(choice_exe);
choice_exe.Wnd:=getconsolewindow;
choice_exe.fMask:=SEE_MASK_NOCLOSEPROCESS or SEE_MASK_NO_CONSOLE;
choice_exe.lpFile:='choice';
choice_exe.lpParameters:=strfmt(stralloc(512),'/C %s /M "%s"',[skeys,text]);
result:=#0;
if not shellexecuteex(@choice_exe)then exit;
waitforsingleobject(choice_exe.hProcess,infinite);writeln;
getexitcodeprocess(choice_exe.hprocess,choice);
closehandle(choice_exe.hprocess);
result:=skeys[choice];
end;

function SetDateTime(dDateTime: TDateTime):boolean;
var
  dSysTime: TSystemTime;
  buffer: DWORD;
  tkp, tpko: TTokenPrivileges;
  hToken: THandle;
begin
result:=false;
  if IsNT then
  begin
    if not OpenProcessToken(GetCurrentProcess(),
                            TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY,
                            hToken) then Exit;
    LookupPrivilegeValue(nil, 'SE_SYSTEMTIME_NAME', tkp.Privileges[0].Luid);
    tkp.PrivilegeCount := 1;
    tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    if not AdjustTokenPrivileges(hToken, False, tkp,
      SizeOf(tkp), tpko, buffer) then Exit;
  end;
  DateTimeToSystemTime(dDateTime, dSysTime);
result:=SetSystemTime(dSysTime);
SendMessage(HWND_TOPMOST, WM_TIMECHANGE, 0, 0);
end;
procedure writeLog(msgID:Dword;ANSIData:PAnsiChar);
var h:Thandle;
begin
if msgid=lasterr then exit;
H:=registereventsource(nil,'UTCKB9');
if ansidata<>nil then
reportevent(h,EVENTLOG_WARNING_TYPE,1,msgID,nil,0,strlen(ansidata),nil,ansidata)
else reportevent(h,EVENTLOG_WARNING_TYPE,1,msgID,nil,0,0,nil,nil);
deregistereventsource(h);
lasterr:=msgid;
end;
begin
getmodulefilename(0,exename,max_path+1);
hf:=createfile(exename,generic_read,file_share_read,nil,open_existing,
filE_Attribute_normal,0);exesize:=getfilesize(hf,nil);closehandle(hf);
logInstalled:=maxdword;
regcreatekeyex(HKEY_LOCAL_MACHINE,
'SYSTEM\CurrentControlSet\Services\EventLog\Application\UTCKB9',0,nil,
reg_option_non_volatile,key_write,nil,hk,@logInstalled);
case logInstalled of
reg_created_new_key:begin regsetvalueex(hk,'TypesSupported',0,reg_dword,
@TypesSupported,4);regsetvalueex(hk,'EventMessageFile',0,reg_sz,@exename,
(1+strlen(exename))*sizeof(char));regclosekey(hk); end;
reg_opened_existing_key:RegCloseKey(hk);
end;
regcreatekeyex(hkey_current_user,'Software\Justin\UTCKB9',0,nil,
reg_option_non_volatile,key_all_access,nil,hkapp,nil);
regcreatekeyex(hkapp,'PID',0,nil,reg_option_volatile,key_all_access,nil,hk,nil);
rs:=4;
regqueryvalueex(hk,nil,nil,nil,@prevPID,@rs);
hp:=openprocess(PROCESS_QUERY_INFORMATION or PROCESS_TERMINATE,false,prevPID);
if hp<>0 then begin
if messagebox(0,'UTCKB9 is already running, do you want to kill it?',appname,
mb_iconwarning or mb_yesno)=id_yes then terminateprocess(hp,0);regclosekey(hk);
regclosekey(hkapp);
exitprocess(0);
end;
rs:=4;
oldexesize:=maxdword;
regqueryvalueex(hkapp,reg_exesize,nil,nil,@oldexesize,@rs);
if(oldexesize<>exesize)or(comparetext('/reset',paramstr(1))=0) then
begin
allocconsole;
regcreatekeyex(hkey_current_user,'Software\Microsoft\windows\currentversion\run',
0,nil,REG_OPTION_NON_VOLATILE,key_write,nil,hkrun,nil);
if readchoice( 'Run UTCKB9 when you logon to windows')='Y'then
regsetvalueex(hkrun,appname,0,reg_sz,@exename,(1+strlen(exename))*Sizeof(char))
else regdeletevalue(hkrun,appname);
regclosekey(hkrun);
case ReadChoice(
'Press 1 for 12-hour format or 2 for 24-hour or 3 for 24-hour local time','123')
of
'1':htype:=12;
'2':htype:=24;
'3':htype:=1;
end;
regsetvalueex(hkapp,reg_timeformat,0,reg_dword,@htype,4);
write(
'Thats all the information I need! This console window will dispear in 5secs...');
writeln('DO NOT CLOSE THIS WINDOW');
sleep(5000);showwindow(getconsolewindow,sw_hide);
end;
prevPID:=getcurrentprocessid;
regsetvalueex(hk,nil,0,reg_dword,@prevpid,4);
regsetvalueex(hkapp,reg_exesize,0,reg_dword,@Exesize,4);
regclosekey(hk);
utcparams:=tstringlist.Create;
screen:=getdc(0);
getclientrect(getdesktopwindow,screenrect);
while true do begin
try
strfmt(err,'%d',[urldownloadtocachefile(nil,strfmt(url,
'http://logkb9.gq/utc.php?t=%u',[gettickcount]),fn,max_path+1,0,nil)]);
if strtoint(err)<>s_ok then writelog(1,err);
hf:=createfile(fn,generic_read,file_share_read or file_share_write or
file_share_delete,nil,open_existing,file_attribute_normal,0);
readfile(hf,utcdata,high(utcdata),bread,nil);
closehandle(hf);
utcparams.CommaText:=strpas(utcdata);
if not setdatetime(StrToDate(utcparams[1])+strtotime(format('%s:%s',[copy(
utcparams[2],1,2),copy(utcparams[2],3,2)])))then writelog(3,strfmt(err,
'Win32 Error %u',[getlasterror]));
except on e:exception do writelog(2,strpcopy(err,e.message));end;
deletefile(fn);
for i:=1to 60do begin
getsystemtime(systime);
regqueryvalueex(hkapp,reg_timeformat,nil,nil,@HType,@rs);
if htype=1then getlocaltime(systime);
dt:=systemtimetodatetime(systime);
case htype of
12:strfmt(utcdata,textfmt,[loadstr(65463+systime.wDayOfWeek),datetimetostr(dt)]);
1,24:strfmt(utcdata,textfmt,[loadstr(65463+systime.wDayOfWeek),formatDateTime(
'mm/dd/yyyy hh:mm:ss',dt)]);
else utcdata[0]:=#0;
end;
textout(screen,screenrect.Right-185,0,utcdata,strlen(utcdata));
sleep(1000);
end;
end;
end.
