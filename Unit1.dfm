object identd: Tidentd
  OldCreateOrder = False
  AllowPause = False
  Dependencies = <
    item
      Name = 'Tcpip'
      IsGroup = False
    end>
  DisplayName = 'identd'
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Left = 192
  Top = 103
  Height = 150
  Width = 215
  object TcpServer1: TTcpServer
    OnAccept = TcpServer1Accept
    Left = 32
    Top = 24
  end
end
