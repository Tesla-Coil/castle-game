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
unit CastleGeneralMenu;

interface

uses GLMenu;

type
  { Just TGLMenu that calls Glw.PostRedisplay and plays a sound
    on each CurrentItem change. }
  TCastleMenu = class(TGLMenu)
    procedure CurrentItemChanged; override;
  end;

implementation

uses SysUtils, GLWindow, CastleWindow;

{ TCastleMenu ---------------------------------------------------------------- }

procedure TCastleMenu.CurrentItemChanged;
begin
  { TODO: sound: stMenuMove }
  Glw.PostRedisplay;
end;

{ initialization / finalization ---------------------------------------------- }

procedure CloseGLW(Glwin: TGLWindow);
begin
  FreeAndNil(MenuFont);
end;

initialization
  Glw.OnCloseList.AppendItem(@CloseGLW);
finalization
end.