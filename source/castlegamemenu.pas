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

uses SysUtils, KambiUtils, KambiStringUtils, GLWindow, GLWinModes,
  OpenGLh, KambiGLUtils, GLWinMessages, CastleWindow,
  VectorMath, CastleHelp, CastlePlay, CastleGeneralMenu,
  CastleControlsMenu;

var
  UserQuit: boolean;
  GLList_ScreenImage: TGLuint;

{ TCastleGameMenu ------------------------------------------------------------ }

type
  TCastleGameMenu = class(TCastleMenu)
    constructor Create;
    procedure CurrentItemSelected; override;
  end;

constructor TCastleGameMenu.Create;
begin
  inherited Create;

  Items.Add('Back to game');
  Items.Add('View last game messages');
  Items.Add('Configure controls');
  Items.Add('End game');

  FixItemsAreas(Glw.Width, Glw.Height);
end;

procedure TCastleGameMenu.CurrentItemSelected;
begin
  case CurrentItem of
    0: UserQuit := true;
    1: ViewGameMessages;
    2: ShowControlsMenu(GLList_ScreenImage, true, true);
    3:
      { At first I did here GameCancel(false), but tests (with Mama)
        show that it's too easy to select this and accidentaly
        end the game. }
      GameCancel(true);
    else raise EInternalError.Create('Menu item unknown');
  end;
end;

{ global things -------------------------------------------------------------- }

var
  GameMenu: TCastleGameMenu;

procedure Resize(Glwin: TGLWindow);
begin
  ProjectionGLOrtho(0, Glwin.Width, 0, Glwin.Height);
end;

procedure Draw(Glwin: TGLWindow);
begin
  glLoadIdentity;
  glRasterPos2i(0, 0);
  glCallList(GLList_ScreenImage);

  GameMenu.Draw;
end;

procedure KeyDown(glwin: TGLWindow; key: TKey; c: char);
begin
  GameMenu.KeyDown(Key, C);
  case Key of
    K_F5: SaveScreen;
    else
      case C of
        CharEscape: UserQuit := true;
      end;
  end;
end;

procedure MouseMove(Glwin: TGLWindow; NewX, NewY: Integer);
begin
  GameMenu.MouseMove(NewX, Glwin.Height - NewY);
end;

procedure MouseUp(Glwin: TGLWindow; Button: TMouseButton);
begin
  GameMenu.MouseUp(Glwin.MouseX, Glwin.Height - Glwin.MouseY, Button);
end;

procedure Idle(Glwin: TGLWindow);
begin
  GameMenu.Idle(Glwin.FpsCompSpeed);
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
  GameMenu := TCastleGameMenu.Create;
end;

procedure CloseGLW(Glwin: TGLWindow);
begin
  FreeAndNil(GameMenu);
end;

initialization
  Glw.OnInitList.AppendItem(@InitGLW);
  Glw.OnCloseList.AppendItem(@CloseGLW);
finalization
end.