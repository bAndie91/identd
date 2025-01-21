# identd
IDENT service server for Win32

It implements more or less the information exposal described in [RFC1413](https://tools.ietf.org/html/rfc1413) plus additional information, see below.

## Socket Communication

Terms "Client" and "Server" are meant in terms of TCP, not in any higher perspective.

* When Client asks for IDENT as it is described in [RFC1413](https://tools.ietf.org/html/rfc1413), he can not only ask
  * `6191,23` (ie. serverPort,clientPort), but also
  * any element wildcarded (`*,23`, `6191,*`, `*,*`), or
  * process name as serverPort (`Explorer.exe,*`, case-insensitive), or
  * executable path as serverPort (`C:\Windows\System\Explorer.exe,*`).
* Server responds not only with
  * `6191,23:USERID:WINNT:stjohns`, but also with 
  * `6191,23:DOMAIN:WINNT:somedomain`, and
  * `6191,23:EXECUTABLE:WINNT:C:\Windows\System\Explorer.exe` if applicable.

# Project issues, bugs, feature requests, ideas

1. clone the repo
2. use [git-bug](https://github.com/git-bug/git-bug) to open a new ticket in this repo
3. find one or more person in the commit history to make contact with, then either
4.a. send your newly created `git-bug` ticket (or patch if you already propose a code change) via email, or
4.b. send the URL of your git clone to a contributor (via email or other channel), and request them to pull (`git-bug` issues and/or branches as well) from you.
