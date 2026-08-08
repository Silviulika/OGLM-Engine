unit Editor.AssetBrowser.Particles;

interface

uses
  dglOpenGL;

type
  TParticleFileBrowserMode = (
    pfbNone,
    pfbLoadParticle,
    pfbSaveParticle
  );

  TParticleFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    PreviewTexturePath: string;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
    FileSize: Int64;
    ModifiedText: string;
    ValidParticleSystem: Boolean;
  end;

  TParticleFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TParticleFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TParticleFileInfo>;
    LastError: string;
  end;

implementation

end.