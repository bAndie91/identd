unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  Sockets, WinSock, ActiveX, ComObj, Variants;

type
  Tidentd = class(TService)
    TcpServer1: TTcpServer;
    procedure TcpServer1Accept(Sender: TObject; ClientSocket: TCustomIpClient);
    function handleRequest(Sender: TObject; ClientSocket: TCustomIpClient): Boolean;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceExecute(Sender: TService);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceShutdown(Sender: TService);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

const
  ANY_SIZE = 1;
  TCP_TABLE_OWNER_PID_ALL = 5;
  MIB_TCP_STATE: array[1..12] of string = (
    'CLOSED',
    'LISTEN',
    'SYN-SENT',
    'SYN-RECEIVED',
    'ESTABLISHED',
    'FIN-WAIT-1',
    'FIN-WAIT-2',
    'CLOSE-WAIT',
    'CLOSING',
    'LAST-ACK',
    'TIME-WAIT',
    'delete TCB'
  );

type
  TCP_TABLE_CLASS = Integer;

type
  PMibTcpRowOwnerPid = ^TMibTcpRowOwnerPid;
  TMibTcpRowOwnerPid  = packed record
    dwState     : DWORD;
    dwLocalAddr : DWORD;
    dwLocalPort : DWORD;
    dwRemoteAddr: DWORD;
    dwRemotePort: DWORD;
    dwOwningPid : DWORD;
  end;

type
  PMIB_TCPTABLE_OWNER_PID  = ^MIB_TCPTABLE_OWNER_PID;
  MIB_TCPTABLE_OWNER_PID = packed record
    dwNumEntries: DWORD;
    table: Array [0..ANY_SIZE - 1] of TMibTcpRowOwnerPid;
  end;

type
  PMyProc = ^TMyProc;
  TMyProc = record
    PID: DWORD;
    lIP, rIP: Integer;
    lIPstr, rIPstr: String;
    lPort, rPort: Word;
    socketStatus: String;
    User, Domain: String;
    SessionID: Integer;
    ExecutablePath, name: String;
  end;


var
  identd: Tidentd;

function GetExtendedTcpTable(pTcpTable: Pointer; dwSize: PDWORD; bOrder: BOOL; lAf: ULONG; TableClass: TCP_TABLE_CLASS; Reserved: ULONG): DWord;
  stdcall; external 'iphlpapi.dll' name 'GetExtendedTcpTable'; // TCP Table + PID


implementation

uses StrUtils;

{$R *.DFM}


procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  identd.Controller(CtrlCode);
end;

function Tidentd.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;


function isInteger(str: String): Boolean;
  var i: Byte;
begin
  Result := False;
  if Length(str) = 0 then Exit;
  for i:=1 to Length(str) do
    begin
      if (str[i] < #$30) or (str[i] > #$39) then
        begin
          Exit;
        end;
    end;
  Result := True;
end;


function GetWin32_Process(var ps: TList): Boolean;
  var
    objWMIService: OLEVariant;
    colItems: OLEVariant;
    colItem: OLEVariant;
    oEnum: IEnumvariant;
    iValue: LongWord;
    User: OLEVariant;
    Domain: OLEVariant;
    p: PMyProc;
  function GetWMIObject(const objectName: String): IDispatch;
    var
      chEaten: Integer;
      BindCtx: IBindCtx;
      Moniker: IMoniker;
  begin
    OleCheck(CreateBindCtx(0, bindCtx));
    OleCheck(MkParseDisplayName(BindCtx, StringToOleStr(objectName), chEaten, Moniker));
    OleCheck(Moniker.BindToObject(BindCtx, nil, IDispatch, Result));
  end;
begin
  Result := False;
  try
	  CoInitialize(nil);
    objWMIService := GetWMIObject('winmgmts:{impersonationLevel=impersonate,(Debug)}\\.\root\cimv2');
    colItems := objWMIService.ExecQuery('SELECT * FROM Win32_Process', 'WQL', 0);
    oEnum := IUnknown(colItems._NewEnum) as IEnumVariant;

    while oEnum.Next(1, colItem, iValue) = 0 do
      begin
        New(p);
        p.PID := colItem.ProcessId;
        if colItem.GetOwner(User, Domain) = 0 then
          begin
            if not VarIsNull(User) then p.User := User;
            if not VarIsNull(Domain) then p.Domain := Domain;
          end;
        p.SessionID := colItem.SessionId;
        if not VarIsNull(colItem.name) then p.name := colItem.name;
        if not VarIsNull(colItem.ExecutablePath) then p.ExecutablePath := colItem.ExecutablePath;
        ps.Add(p);
        colItem := Unassigned;
        VarClear(colItem);
      end;
  finally
    VarClear(objWMIService);
    VarClear(colItems);
    VarClear(colItem);
    VarClear(User);
    VarClear(Domain);
 		CoUninitialize;
    Result := True;
  end;
end;


function NetStat(var ns: TList): Boolean;
  var
    Error: DWORD;
    TableSize: DWORD;
    i: integer;
    IpAddress: in_addr;
    pTcpTable: PMIB_TCPTABLE_OWNER_PID;
    p: PMyProc;
begin
  Result := False;
  try
  	TableSize := 0;
  	{ Get the size o the tcp table }
  	Error := GetExtendedTcpTable(nil, @TableSize, False, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
  	if Error = ERROR_INSUFFICIENT_BUFFER then
  	  begin
    		{ Alocate the buffer }
  	  	GetMem(pTcpTable, TableSize);
        try
  		    { Get the tcp table data }
    		  if GetExtendedTcpTable(pTcpTable, @TableSize, TRUE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) = NO_ERROR then
  	    		for i := 0 to pTcpTable.dwNumEntries - 1 do
      			  begin
                New(p);
      		  		p.PID := pTcpTable.Table[i].dwOwningPid;
                IpAddress.s_addr := pTcpTable.Table[i].dwRemoteAddr;
                p.rIP := IpAddress.s_addr;
        				p.rIPstr := String(inet_ntoa(IpAddress));
                IpAddress.s_addr := pTcpTable.Table[i].dwLocalAddr;
        				p.lIP := IpAddress.s_addr;
        				p.lIPstr := string(inet_ntoa(IpAddress));
                p.rPort := htons(pTcpTable.Table[i].dwRemotePort);
                p.lPort := htons(pTcpTable.Table[i].dwLocalPort);
                p.socketStatus := MIB_TCP_STATE[pTcpTable.Table[i].dwState];
                ns.Add(p);
              end;
        finally
      		FreeMem(pTcpTable);
        end;
      end
    else
	  	raise Exception.Create('GetExtendedTcpTable:'+IntToStr(Error));
  finally
    Result := True;
	end;
end;


procedure Tidentd.TcpServer1Accept(Sender: TObject; ClientSocket: TCustomIpClient);
begin
  repeat until not handleRequest(Sender, ClientSocket);
  ClientSocket.Close;
end;


function Tidentd.handleRequest(Sender: TObject; ClientSocket: TCustomIpClient): Boolean;
  var
    question: String;
    qMyPort, qHerPort: String;
    sl, pl: TList;
    si, pi: Integer;
    sr, pr: PMyProc;
    found: Boolean;
    resp: String;
    i: Cardinal;
begin
  i := ClientSocket.BytesReceived;
  question := ClientSocket.Receiveln(#$0A);
  Result := i < ClientSocket.BytesReceived;
  if not Result then Exit;
  
  question := Trim(question);
  qMyPort := LeftStr(question, Pos(',', question)-1);
  qHerPort := RightStr(question, Length(question)-Pos(',', question));
  LogMessage(ClientSocket.RemoteHost+': '+question, EVENTLOG_INFORMATION_TYPE, 0, 0); // FIXME
  if (qMyPort <> '') and ((qHerPort = '*') or isInteger(qHerPort)) then
    begin
      sl := TList.Create;
      pl := TList.Create;
      try
        NetStat(sl);
        GetWin32_Process(pl);
        found := False;

        for si:=0 to sl.Count - 1 do
          begin
            sr := sl.Items[si];
            for pi:=0 to pl.Count - 1 do
              begin
                pr := pl.Items[pi];
                if pr.PID = sr.PID then
                  begin
                    sr.User := pr.User;
                    sr.Domain := pr.Domain;
                    sr.SessionID := pr.SessionID;
                    sr.ExecutablePath := pr.ExecutablePath;
                    sr.name := pr.name;
                    Break;
                  end;
              end;
            if (
                 (sr.rIPstr = ClientSocket.RemoteHost) and
                 (
                   ((IntToStr(sr.lPort) = qMyPort) or (qMyPort = '*')) and
                   ((IntToStr(sr.rPort) = qHerPort) or (qHerPort = '*'))
                  )
                ) or
               (
                 (
                   (LowerCase(qMyPort) = LowerCase(sr.ExecutablePath)) or
                   (LowerCase(qMyPort) = LowerCase(sr.name))
                  ) and
                 (sr.socketStatus = 'LISTEN')
                )
            then
              begin
                found := True;
                resp := IntToStr(sr.lPort)+','+IntToStr(sr.rPort);
                ClientSocket.Sendln(resp+':USERID:WINNT:'+sr.User);
                if sr.Domain <> '' then ClientSocket.Sendln(resp+':DOMAIN:WINNT:'+sr.Domain);
                if sr.ExecutablePath <> '' then ClientSocket.Sendln(resp+':EXECUTABLE:WINNT:'+sr.ExecutablePath);
              end;
          end;
        if not found then
          ClientSocket.Sendln(question+':ERROR:NO-USER');
      except
        on E: Exception do ClientSocket.Sendln(question+':ERROR:UNKNOWN-ERROR:'+E.ClassName+':'+E.Message);
      end;
      for si:=0 to sl.Count - 1 do FreeMem(sl.Items[si]);
      for pi:=0 to pl.Count - 1 do FreeMem(pl.Items[pi]);
      sl.Free;
      pl.Free;
    end
  else
    ClientSocket.Sendln(question+':ERROR:INVALID-PORT');
end;


procedure Tidentd.ServiceStart(Sender: TService; var Started: Boolean);
begin
  Started := True;
end;


procedure Tidentd.ServiceExecute(Sender: TService);
begin
  with TcpServer1 do
    begin
      LocalHost := '0.0.0.0';
      LocalPort := '113';
      Active := True;
      while not Terminated and Active do
        begin
          //WaitForConnection;
          ServiceThread.ProcessRequests(True);
        end;
      Active := False;
      Close;
    end;
end;

procedure Tidentd.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  Stopped := True;
  ErrCode := 0;
end;

procedure Tidentd.ServiceShutdown(Sender: TService);
  var Stopped: Boolean;
begin
  ServiceStop(Sender, Stopped);
end;

end.

