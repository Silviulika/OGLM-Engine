unit Editor.Panels.Audio;

interface

type
  TAudioFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TAudioTestState = record
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..511] of AnsiChar;
    Loop: Boolean;
    Volume: Single;
    MasterVolume: Single;
    Items: TArray<TAudioFileInfo>;
    LastError: string;
  end;

implementation

end.