{
  Copyright 2007-2010 Michalis Kamburelis.

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

{ Background stuff displayed under the start menu.

  To allow a wide range of 2D and 3D effects, we simply initialize here
  a full castle level instance in BackgroundLevel. This level may be animated,
  it can even have some interactive stuff (like touch sensors etc.,
  although not used now).
  So we can make this background level to really show off some features
  and tease the player before (s)he clicks "New Game".
  At the same time, I have here the ability to insert some special
  things that cannot be really added to the game (e.g. some 2D effect
  that depends that the camera is on particular position --- in actual
  game we can't guarantee this, but in the game we can just set camera
  still).

  We could also place some creatures / items on this level
  (although not done for now, as we defer loading creatures / items
  until actual game).

  So this unit is somewhat equivalent to CastlePlay unit,
  but different. CastlePlay unit has global Player and Level instances.
  This unit doesn't use them (so it's a design decision that this
  unit @italic(doesn't use CastlePlay unit (even in the implementation))).
  This unit has own BackgroundLevel instance (and no player, articial
  camera is created by BackgroundCreate).
}
unit CastleBackgroundLevel;

interface

uses GLWindow, UIControls, CastleLevel;

var
  BackgroundLevel: TLevel;
  BackgroundCaptions: TUIControl;

{ Create / destroy BackgroundLevel and BackgroundCaptions instances.
  @groupBegin }
procedure BackgroundCreate;
procedure BackgroundDestroy;
{ @groupEnd }

implementation

uses SysUtils,
  Cameras, GL, GLU, GLExt, BackgroundGL, KambiGLUtils, GLImages,
  VRMLGLHeadlight, KambiFilesUtils, Images, VectorMath,
  CastleWindow, CastleLevelAvailable, CastleVideoOptions,
  VRMLGLScene, RenderStateUnit;

{ TBackgroundCaptions -------------------------------------------------------- }

type
  TBackgroundCaptions = class(TUIControl)
  private
    GLList_Caption: TGLuint;
    {CaptionWidth, }CaptionHeight: Cardinal;
  public
    function DrawStyle: TUIControlDrawStyle; override;
    procedure Draw(const Focused: boolean); override;
    procedure GLContextInit; override;
    procedure GLContextClose; override;
  end;

function TBackgroundCaptions.DrawStyle: TUIControlDrawStyle;
begin
  Result := ds2D;
end;

procedure TBackgroundCaptions.Draw(const Focused: boolean);
begin
  glPushAttrib(GL_ENABLE_BIT);
    glRasterPos2i(0, ContainerHeight - CaptionHeight);

    glEnable(GL_ALPHA_TEST);
    glAlphaFunc(GL_GREATER, 0.5);
    glCallList(GLList_Caption);
  glPopAttrib;
end;

procedure TBackgroundCaptions.GLContextInit;
var
  ImageCaption: TImage;
begin
  ImageCaption := LoadImage(ProgramDataPath + 'data' +
    PathDelim + 'menu_bg' + PathDelim + 'caption.png', [], [], 0, 0);
  try
    GLList_Caption := ImageDrawToDisplayList(ImageCaption);
    {CaptionWidth := ImageCaption.Width; useless for now}
    CaptionHeight := ImageCaption.Height;
  finally FreeAndNil(ImageCaption) end;
end;

procedure TBackgroundCaptions.GLContextClose;
begin
  glFreeDisplayList(GLList_Caption);
end;

{ routines ------------------------------------------------------------------- }

procedure BackgroundCreate;
begin
  { initialize BackgroundLevel }
  BackgroundLevel := LevelsAvailable.FindName(LevelsAvailable.MenuBackgroundLevelName).
    CreateLevel(true);

  { initialize BackgroundLevel.Camera }
  BackgroundLevel.Camera := TWalkCamera.Create(BackgroundLevel);
  (BackgroundLevel.Camera as TWalkCamera).Init(
    BackgroundLevel.InitialPosition,
    BackgroundLevel.InitialDirection,
    BackgroundLevel.InitialUp,
    BackgroundLevel.GravityUp, 0.0, 0.0 { unused, we don't use Gravity here });

  { Do not allow to move the camera in any way.
    We should also disable any other interaction with the scene,
    in case in the future TLevel will enable ProcessEvents and some animation
    through it --- but we can also depend that background level will not
    have any TouchSensors, KeySensors etc. }
  BackgroundLevel.Camera.IgnoreAllInputs := true;

  BackgroundCaptions := TBackgroundCaptions.Create(nil);
end;

procedure BackgroundDestroy;
begin
  FreeAndNil(BackgroundLevel);
  FreeAndNil(BackgroundCaptions);
end;

end.
