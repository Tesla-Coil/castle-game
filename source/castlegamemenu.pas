{
  Copyright 2006 Michalis Kamburelis.

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
}

{ }
unit CastleGameMenu;

interface

procedure ShowGameMenu;

implementation

uses SysUtils, Classes, KambiUtils, KambiStringUtils, GLWindow, GLWinModes,
  OpenGLh, KambiGLUtils, GLWinMessages, CastleWindow,
  VectorMath, CastleHelp, CastlePlay, CastleGeneralMenu,
  CastleControlsMenu, CastleKeys, CastleCreatures;

{ TCastleMenu descendants interface ------------------------------------------ }

type
  TGameMenu = class(TCastleMenu)
    constructor Create;
    procedure CurrentItemSelected; override;
  end;

  TDebugMenu = class(TCastleMenu)
    constructor Create;
    procedure CurrentItemSelected; override;
  end;

{ ----------------------------------------------------------------------------
  global vars (used by TCastleMenu descendants implementation) }

var
  UserQuit: boolean;
  GLList_ScreenImage: TGLuint;
  CurrentMenu: TCastleMenu;
  GameMenu: TGameMenu;
  DebugMenu: TDebugMenu;

{ TGameMenu ------------------------------------------------------------ }

constructor TGameMenu.Create;
begin
  inherited Create;

  Items.Add('Back to game');
  Items.Add('View last game messages');
  Items.Add('Configure controls');
  Items.Add('End game');
  Items.Add('Debug (cheating) options');

  FixItemsAreas(Glw.Width, Glw.Height);
end;

procedure TGameMenu.CurrentItemSelected;
begin
  case CurrentItem of
    0: UserQuit := true;
    1: ViewGameMessages;
    2: ShowControlsMenu(GLList_ScreenImage, true, true);
    3: { At first I did here GameCancel(false), but tests (with Mama)
         show that it's too easy to select this and accidentaly
         end the game. }
       GameCancel(true);
    4: CurrentMenu := DebugMenu;
    else raise EInternalError.Create('Menu item unknown');
  end;
end;

{ TDebugMenu ------------------------------------------------------------ }

constructor TDebugMenu.Create;
begin
  inherited Create;

  Items.Add('Player.Life := Player.MaxLife');
  Items.Add('Show creatures on level info');
  Items.Add('Add creature to level');
  Items.Add('Back to main menu');

  FixItemsAreas(Glw.Width, Glw.Height);
end;

procedure TDebugMenu.CurrentItemSelected;

  procedure PlayerMaxLife;
  begin
    if Player.Dead then
      MessageOK(Glw, 'No can do. You are dead.', taLeft) else
    begin
      Player.Life := Player.MaxLife;
      UserQuit := true;
    end;
  end;

  procedure ShowLevelCreaturesInfo;
  var
    I: Integer;
    S: TStringList;
  begin
    S := TStringList.Create;
    try
      S.Append(Format('%d creatures on level:', [Level.Creatures.Count]));
      S.Append('Index: Kind, Position, Life / MaxLife');
      S.Append('');

      for I := 0 to Level.Creatures.High do
        S.Append(Format('%d: %s, %s, %s / %s',
          [ I, Level.Creatures[I].Kind.VRMLNodeName,
            VectorToNiceStr(Level.Creatures[I].LegsPosition),
            FloatToNiceStr(Level.Creatures[I].Life),
            FloatToNiceStr(Level.Creatures[I].MaxLife) ]));

      MessageOK(Glw, S, taLeft);
    finally S.Free end;
  end;

  function ChooseCreatureKind: TCreatureKind;
  var
    I, ResultIndex: Integer;
    S: TStringList;
  begin
    S := TStringList.Create;
    try
      S.Append('Choose creature kind number: ');
      S.Append('');

      for I := 0 to CreaturesKinds.High do
        S.Append(Format('%d: %s',
          [ I, CreaturesKinds[I].VRMLNodeName ]));

      ResultIndex := Clamped(MessageInputCardinal(Glw, S.Text, taLeft, 0), 0,
        CreaturesKinds.High);

      Result := CreaturesKinds[ResultIndex];
    finally S.Free end;
  end;

  procedure AddLevelCreature;
  var
    Position: TVector3Single;
    Direction: TVector3Single;
    Kind: TCreatureKind;
  begin
    Position := VectorAdd(Player.Navigator.CameraPos,
      VectorAdjustToLength(Player.Navigator.CameraDir, 10));
    Direction := Player.Navigator.CameraDir;
    Kind := ChooseCreatureKind;
    Level.Creatures.Add(
      Kind.CreateDefaultCreature(Position, Direction, Level.AnimationTime));

    UserQuit := true;
  end;

begin
  case CurrentItem of
    0: PlayerMaxLife;
    1: ShowLevelCreaturesInfo;
    2: AddLevelCreature;
    3: CurrentMenu := GameMenu;
    else raise EInternalError.Create('Menu item unknown');
  end;
end;

{ global things -------------------------------------------------------------- }

procedure Resize(Glwin: TGLWindow);
begin
  ProjectionGLOrtho(0, Glwin.Width, 0, Glwin.Height);
end;

procedure Draw(Glwin: TGLWindow);
begin
  glLoadIdentity;
  glRasterPos2i(0, 0);
  glCallList(GLList_ScreenImage);

  CurrentMenu.Draw;
end;

procedure KeyDown(glwin: TGLWindow; key: TKey; c: char);
begin
  CurrentMenu.KeyDown(Key, C);
  if Key = CastleKey_SaveScreen.Value then
    SaveScreen else
  case C of
    CharEscape: UserQuit := true;
  end;
end;

procedure MouseMove(Glwin: TGLWindow; NewX, NewY: Integer);
begin
  CurrentMenu.MouseMove(NewX, Glwin.Height - NewY);
end;

procedure MouseUp(Glwin: TGLWindow; Button: TMouseButton);
begin
  CurrentMenu.MouseUp(Glwin.MouseX, Glwin.Height - Glwin.MouseY, Button);
end;

procedure Idle(Glwin: TGLWindow);
begin
  CurrentMenu.Idle(Glwin.FpsCompSpeed);
end;

procedure CloseQuery(Glwin: TGLWindow);
begin
  GameCancel(true);
end;

procedure ShowGameMenu;
var
  SavedMode: TGLMode;
begin
  GLList_ScreenImage := Glw.SaveScreenToDispList;
  try
    SavedMode := TGLMode.Create(Glw, GL_ENABLE_BIT, true);
    try
      SetStandardGLWindowState(Glw, Draw, CloseQuery, Resize,
        nil, false, true { FPSActive is needed for FpsCompSpeed in Idle. },
        false, K_None, #0, false, false);

      { Otherwise messages don't look good, because the text is mixed
        with the menu text. }
      GLWinMessagesTheme.RectColor[3] := 1.0;

      Glw.OnKeyDown := KeyDown;
      Glw.OnMouseUp := MouseUp;
      Glw.OnMouseMove := MouseMove;
      Glw.OnIdle := Idle;

      Glw.EventResize;

      CurrentMenu := GameMenu;
      UserQuit := false;

      glDisable(GL_LIGHTING);

      repeat
        Glwm.ProcessMessage(true);
      until GameEnded or UserQuit;

    finally FreeAndNil(SavedMode); end;
  finally glFreeDisplayList(GLList_ScreenImage); end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure InitGLW(Glwin: TGLWindow);
begin
  GameMenu := TGameMenu.Create;
  DebugMenu := TDebugMenu.Create;
  CurrentMenu := GameMenu;
end;

procedure CloseGLW(Glwin: TGLWindow);
begin
  CurrentMenu := nil;
  FreeAndNil(GameMenu);
  FreeAndNil(DebugMenu);
end;

initialization
  Glw.OnInitList.AppendItem(@InitGLW);
  Glw.OnCloseList.AppendItem(@CloseGLW);
finalization
end.