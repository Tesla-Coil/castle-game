{
  Copyright 2010-2011 Michalis Kamburelis.

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

{ Apply to 3D model file some castle-specific processing,
  and then output the processed version on stdout.
  Call with one command-line parameter: the source filename.
  We automatically detect the type of processing to apply
  based on the basename of this file.

  Example usage: pipe processed fountain level to view3dscene:

    cd data/levels/fountain/
    castle-process-3d-model fountain_final.wrl | view3dscene -

  What processing is done?

  - castle-specific processing, the same one as automatically used
    during level load.

    (similar processing may be also used for other 3D models,
    e.g. creatures or items, in the future).
    This adds to 3D files some features that could not be generated by
    Blender exporter (and cannot be added by hand by adding outside
    file Inline'ing the source file).
    For example, normal maps and GLSL shaders are added to 3D level files
    during this processing (because they cannot be generated by Blender
    exporter, after all e.g. normalMap are only Kambi vrml extension.)

    This processing is automatically done by castle when loading 3D files.
    This program becomes useful only when you want to view castle's 3D files,
    with this processing applied, in other programs, like view3dscene.

  - Also, Inlines are resolved. That is, VRML/X3D "Inline" nodes are replaced
    with their actual files' contents. Without this, processing inside
    inlines' content would not be saved, and e.g. using this program with
    data/levels/fountain/fountain_final.wrl would be useless
    (as the actual normal maps would be added inside inline'd fountain.wrl only).

  - Also "stub" boxes (designating creatures, items, waypoints, sectors
    and many more) are removed. This just makes viewing 3D models in other
    programs better, as these stub boxes usually only get in the way.
}

uses SysUtils, KambiUtils, KambiClassUtils, VRMLNodes, X3DLoad,
  KambiStringUtils, CastleVRMLProcessing, KambiParameters;

{ Remove special "stub" nodes, for castle creatures, items etc.
  This is purely for testing purposes (e.g. to view castle levels
  in view3dscene), in actual game you want to remove them more intelligently
  (actually adding creatures, items, etc. at designated places). }
procedure RemoveSpecialCastleNodes(Node: TVRMLNode); forward;

{ Resolve inlines, that is replace all Inline nodes with Group nodes containing
  their contents. }
procedure ResolveInlines(Node: TVRMLNode); forward;

{ RemoveSpecialCastleNodes --------------------------------------------------- }

type
  THelperSpecialCastleNodes = class
    class procedure Remove(ParentNode: TVRMLNode; var Node: TVRMLNode);
  end;

class procedure THelperSpecialCastleNodes.Remove(
  ParentNode: TVRMLNode; var Node: TVRMLNode);
begin
  if (Node.NodeName = 'LevelBox') or (Node.NodeName = 'ME_LevelBox') or
     (Node.NodeName = 'WaterBox') or
     IsPrefix('Crea', Node.NodeName) or IsPrefix('OB_Crea', Node.NodeName) or
     IsPrefix('Item', Node.NodeName) or IsPrefix('OB_Item', Node.NodeName) or
     IsPrefix('Waypoint', Node.NodeName) or
     IsPrefix('Sector', Node.NodeName) or
     { Actually below are special only on specific levels }
     (Node.NodeName = 'LevelExitBox') or
     IsPrefix('WerewolfAppear_', Node.NodeName) or
     (Node.NodeName = 'GateExitBox') or
     (Node.NodeName = 'Teleport1Box') or
     (Node.NodeName = 'Teleport2Box') or
     (Node.NodeName = 'SacrilegeBox') or
     IsPrefix('SacrilegeGhost_', Node.NodeName) or
     IsPrefix('SwordGhost_', Node.NodeName) or
     (Node.NodeName = 'Elevator49DownBox') or
     (Node.NodeName = 'Elev9a9bPickBox') then
    Node := nil;
end;

procedure RemoveSpecialCastleNodes(Node: TVRMLNode);
begin
  Node.EnumerateReplaceChildren(@THelperSpecialCastleNodes(nil).Remove);
end;

{ ResolveInlines ------------------------------------------------------------- }

type
  TEnumerateResolveInlines = class
  public
    class procedure Enumerate(ParentNode: TVRMLNode; var Node: TVRMLNode);
  end;

class procedure TEnumerateResolveInlines.Enumerate(ParentNode: TVRMLNode; var Node: TVRMLNode);
var
  G2: TNodeGroup;
  G1: TVRMLNode;
  Inlined: TVRMLNode;
begin
  { Replace VRML 1.0 inlines with VRML 1.0 Group or Separator node.
    Note that TNodeWWWInline actually descends from TNodeInline now,
    so the check for TNodeWWWInline must be 1st. }
  if Node is TNodeWWWInline then
  begin
    TNodeWWWInline(Node).LoadInlined(false);
    Inlined := TNodeWWWInline(Node).Inlined;

    if Inlined <> nil then
    begin
      if TNodeWWWInline(Node).FdSeparate.Value then
        G1 := TNodeSeparator.Create(Node.NodeName, Node.WWWBasePath) else
        G1 := TNodeGroup_1.Create(Node.NodeName, Node.WWWBasePath);
      G1.PositionInParent := Node.PositionInParent;
      G1.VRML1ChildAdd(Inlined);
      Node := G1;
    end;
  end else
  { Replace VRML >= 2.0 inlines with VRML 2.0 / X3D Group node }
  if Node is TNodeInline then
  begin
    TNodeInline(Node).LoadInlined(false);
    Inlined := TNodeInline(Node).Inlined;

    if Inlined <> nil then
    begin
      G2 := TNodeGroup.Create(Node.NodeName, Node.WWWBasePath);
      { update PositionInParent,
        to make the resulting VRML look more similar to original
        (otherwise resolved inline could move up in the file) }
      G2.PositionInParent := Node.PositionInParent;
      G2.FdChildren.Add(Inlined);
      Node := G2;
    end;
  end;
end;

procedure ResolveInlines(Node: TVRMLNode);
begin
  Node.EnumerateReplaceChildren(@TEnumerateResolveInlines(nil).Enumerate);
end;

{ main ----------------------------------------------------------------------- }

var
  BaseName, FileName: string;
  Model: TVRMLNode;
begin
  Parameters.CheckHigh(1);
  FileName := Parameters[1];

  Model := LoadVRML(FileName);
  try
    BaseName := DeleteFileExt(ExtractFileName(FileName));

    ResolveInlines(Model);

    if SameText(BaseName, 'fountain_final') or
       SameText(BaseName, 'fountain') then
      LevelFountainProcess(Model);

    RemoveSpecialCastleNodes(Model);

    SaveVRML(Model, StdOutStream, 'castle-process-3d-model', '', xeClassic);
  finally FreeAndNil(Model) end;
end.
