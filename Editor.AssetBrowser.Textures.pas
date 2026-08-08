unit Editor.AssetBrowser.Textures;

interface

uses
  dglOpenGL;

type
  TTextureAssetInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    LibraryIndex: Integer;
    MaterialIndex: Integer;
    TextureIndex: Integer;
    Items: TArray<TTextureAssetInfo>;
    LastError: string;
  end;

  TParticleTextureFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TParticleTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TParticleTextureFileInfo>;
    LastError: string;
  end;

  TBillboardTextureFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TBillboardTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TBillboardTextureFileInfo>;
    LastError: string;
  end;

implementation

end.