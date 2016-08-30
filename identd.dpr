program Project1;


uses
  SvcMgr,
  Unit1 in 'Unit1.pas' {identd: TService};

begin
  Application.Initialize;
  Application.Title := 'identd';
  Application.CreateForm(Tidentd, identd);
  Application.Run;
end.
