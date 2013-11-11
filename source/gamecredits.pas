{
  Copyright 2007-2013 Michalis Kamburelis.

  This file is part of "castle".

  "castle" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "castle" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "castle"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
unit GameCredits;

interface

uses CastleWindow, CastleUIControls, X3DNodes, CastleSceneManager;

{ Show credits. }
procedure ShowCredits(ControlsUnder: TUIControlList;
  SceneManagerUnder: TCastleSceneManager);

implementation

uses SysUtils, Classes, CastleGLUtils, CastleMessages,
  CastleGameNotifications, CastleStringUtils, CastleWindowModes,
  GamePlay, GameWindow,
  GameVideoOptions, CastleVectors, CastleScene, CastleFilesUtils,
  GameHelp, CastleUtils, X3DFields, CastleTimeUtils, CastleKeysMouse, Castle3D;

var
  UserQuit: boolean;

{ TCredits ------------------------------------------------------------------- }

type
  TCredits = class(T3DTransform)
  public
    AnimationTime, AnimationSpeed, AnimationEnd: TFloatTime;
    Scene: TCastleScene;
    constructor Create(AOwner: TComponent); override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  end;

constructor TCredits.Create(AOwner: TComponent);
var
  VRMLContents: string;
  Info: TMFString;
begin
  inherited;

  VRMLContents := FileToString(ApplicationData('menu_bg/credits.wrl'));
  StringReplaceAllTo1st(VRMLContents, '$SCastleVersion', SCastleVersion);
  StringReplaceAllTo1st(VRMLContents, '$SCastleWWW', 'WWW: ' + CastleURL);
  StringReplaceAllTo1st(VRMLContents, '$SCompilerDescription', SCompilerDescription);

  Scene := TCastleScene.Create(Self);
  Scene.Load(LoadX3DClassicFromString(VRMLContents, ''), true);

  Add(Scene);

  Info := (Scene.RootNode.FindNodeByName(TWorldInfoNode,
    'MainInfo', true) as TWorldInfoNode).FdInfo;
  AnimationSpeed := StrToFloat(Info.Items[1]);
  AnimationEnd := StrToFloat(Info.Items[2]);
end;

procedure TCredits.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  AnimationTime := AnimationTime + SecondsPassed;
  Translation := Vector3Single(0, AnimationSpeed * AnimationTime, 0);
  if AnimationTime > AnimationEnd then
    UserQuit := true;
end;

{ others --------------------------------------------------------------------- }

var
  Credits: TCredits;
  CreditsSceneManager: TCastleSceneManager;

procedure CloseQuery(Sender: TCastleWindowBase);
begin
  MessageOK(Window, 'You can''t exit now.');
end;

procedure Press(Window: TCastleWindowBase; const Event: TInputPressRelease);
begin
  if Event.IsKey(CharEscape) or
     Event.IsKey(CharEnter) or
     Event.IsKey(' ') or
     { any mouse press ends credits }
     (Event.EventType = itMouseButton) then
    UserQuit := true;
end;

procedure ShowCredits(ControlsUnder: TUIControlList;
  SceneManagerUnder: TCastleSceneManager);
var
  SavedMode: TGLMode;
begin
  SavedMode := TGLMode.CreateReset(Window, nil, nil, @CloseQuery);
  try
    Window.AutoRedisplay := true; { scrolling text animation }

    Window.OnPress := @Press;

    UserQuit := false;
    Credits.AnimationTime := 0;

    Window.Controls.Add(Notifications);
    Window.Controls.AddList(ControlsUnder);

    Window.Controls.InsertFront(CreditsSceneManager);

    repeat
      Application.ProcessMessage(true, true);
    until UserQuit;
  finally FreeAndNil(SavedMode) end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure WindowOpen;
begin
  Credits := TCredits.Create(nil);

  { We want to create separate scene manager for credits display because:
    - we want it displayed always on top (so depth buffer should be cleared)
      of the background,
    - ignoring UseGlobalLights of the background level.
    - with own projection, regardles of the background level projection.
    - with own size. }
  CreditsSceneManager := TCastleSceneManager.Create(nil);
  CreditsSceneManager.FullSize := false;
  CreditsSceneManager.Left := 25;
  CreditsSceneManager.Bottom := 20;
  CreditsSceneManager.Width := Max(0, Window.Width - CreditsSceneManager.Left * 2);
  CreditsSceneManager.Height := Max(0, Window.Height - CreditsSceneManager.Bottom * 2 - 160);
  CreditsSceneManager.Transparent := true;

  CreditsSceneManager.Items.Add(Credits);
  CreditsSceneManager.MainScene := Credits.Scene;
  
  CreditsSceneManager.Camera := CreditsSceneManager.CreateDefaultCamera;
  CreditsSceneManager.Camera.Input := [];
end;

procedure WindowClose;
begin
  FreeAndNil(Credits);
  FreeAndNil(CreditsSceneManager);
end;

initialization
  OnGLContextOpen.Add(@WindowOpen);
  OnGLContextClose.Add(@WindowClose);
end.
