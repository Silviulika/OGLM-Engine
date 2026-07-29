program OGLM_Game;

uses
  Vcl.Forms,
  OGLM_GameForm in 'OGLM_GameForm.pas' {GameForm};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TGameForm, GameForm);
  Application.Run;
end.
