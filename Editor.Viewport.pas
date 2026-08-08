unit Editor.Viewport;

interface

type
  TRenderTextureToolState = record
    Active: Boolean;
    Pending: Boolean;
    Width: Integer;
    Height: Integer;
    AntialiasingSamples: Integer;
    FileName: array[0..255] of AnsiChar;
    LastOutputFileName: string;
    LastError: string;
  end;

implementation

end.