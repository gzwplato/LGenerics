program TestLGTreeSet;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, LGTreeSetTest, GuiTestRunner;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

