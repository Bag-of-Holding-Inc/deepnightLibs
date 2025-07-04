package dn.heaps.slib;

import h2d.Drawable;
import dn.heaps.slib.*;
import dn.heaps.slib.SpriteLib;
import dn.M;

#if !heaps
#error "Heaps required"
#end

class HSprite extends h2d.Drawable implements SpriteInterface {
	public var anim(get,never) : AnimManager;
	var _animManager : AnimManager;

	public var lib : SpriteLib;
	public var groupName : Null<String>;
	public var group : Null<LibGroup>;
	public var frame(default,null) : Int;
	public var frameData : Null<FrameData>;
	public var pivot : SpritePivot;
	public var destroyed : Bool;
	public var animAllocated(get,never) : Bool;
	public var animVisibleFlag:Bool = true;

	public var onAnimManAlloc : Null<AnimManager->Void>;
	public var onFrameChange : Null<Void->Void>;

	var customTile  : Null<h2d.Tile>;
	var rawTile  : h2d.Tile;
	var lastPage : Int;
	public var tile(get,never) : h2d.Tile;

	// Skew values
	public var skewX = 0.;
	public var skewY = 0.;

	public function new(?l:SpriteLib, ?g:String, ?f=0, ?parent:h2d.Object) {
		super(parent);
		destroyed = false;

		pivot = new SpritePivot();
		lastPage = -1;

		if( l!=null )
			set(l, g, f);
		else
			setEmptyTexture();
	}

	public static function fromTile(t:h2d.Tile, ?parent:h2d.Object) : HSprite {
		var s = new HSprite(parent);
		s.useCustomTile(t);
		return s;
	}

	override function toString() return "HSprite_"+groupName+"["+frame+"]";

	inline function get_anim() {
		if( _animManager==null ) {
			_animManager = new dn.heaps.slib.AnimManager(this);
			if( onAnimManAlloc!=null )
				onAnimManAlloc(_animManager);
		}

		return _animManager;
	}

	inline function get_animAllocated() return _animManager!=null;

	public inline function disposeAnimManager() {
		if( animAllocated ) {
			_animManager.destroy();
			_animManager = null;
		}
	}

	public inline function setPos(x:Float, y:Float) setPosition(x,y);

	public function setTexture(t : h3d.mat.Texture) {
		rawTile = h2d.Tile.fromTexture(t);
	}

	public function useCustomTile(t:h2d.Tile) {
		customTile = t;
	}

	public inline function isUsingCustomTile(?t:h2d.Tile) {
		return t==null && customTile!=null  ||  t!=null && customTile==t;
	}

	public function setEmptyTexture() {
		#if debug
		rawTile = h2d.Tile.fromColor(0x80FF00,4,4);
		#else
		rawTile = h2d.Tile.fromColor(0x0,4,4, 0);
		#end
	}

	public inline function set( ?l:SpriteLib, ?g:String, ?frame=0, ?stopAllAnims=false ) {
		if( l!=null ) {
			// Update internal tile
			if ( l.pages==null || l.pages.length == 0 )
				throw "sprite sheet has no backing texture, please generate one";

			// Reset existing frame data
			if( g==null ) {
				groupName = null;
				group = null;
				frameData = null;
			}

			// Register SpriteLib
			if( allocated && lib != null )
				lib.removeChild(this);
			lib = l;
			if( allocated )
				lib.addChild(this);
			if( pivot.isUndefined )
				setCenterRatio(lib.defaultCenterX, lib.defaultCenterY);
		}

		if( g!=null && g!=groupName )
			groupName = g;

		if( isReady() ) {
			if( stopAllAnims && _animManager!=null )
				anim.stopWithoutStateAnims();

			group = lib.getGroup(groupName);
			frameData = lib.getFrameData(groupName, frame);
			if( frameData==null )
				throw 'Unknown frame: $groupName($frame)';

			if (rawTile == null) rawTile = lib.pages[frameData.page].clone();
			else rawTile.switchTexture(lib.pages[frameData.page]);
			lastPage = frameData.page;
			setFrame(frame);
		}
		else
			setEmptyTexture();
	}

	public inline function setRandom(?l:SpriteLib, g:String, ?rndFunc:Int->Int) {
		set(l, g, lib.getRandomFrame(g, rndFunc==null ? Std.random : rndFunc));
	}

	public inline function setRandomFrame(?rndFunc:Int->Int) {
		if( isReady() )
			setRandom(groupName, rndFunc==null ? Std.random : rndFunc);
	}

	public inline function isGroup(k) {
		return groupName==k;
	}

	public inline function is(k, ?f=-1) return groupName==k && (f<0 || frame==f);

	public inline function isReady() {
		return !destroyed && lib!=null && groupName!=null;
	}

	public function setFrame(f:Int) {
		frame = f;

		if( isReady() ) {
			var prev = frameData;
			frameData = lib.getFrameData(groupName, frame);
			if( frameData==null )
				throw 'Unknown frame: $groupName($frame)';

			if( lastFrame != frameData.page ) {
				rawTile.switchTexture(lib.pages[frameData.page]);
				lastPage = frameData.page;
			}

			if( onFrameChange!=null )
				onFrameChange();
		}
	}

	public function fitToBox(w:Float, ?h:Null<Float>, ?useFrameDataRealSize=false) {
		if( useFrameDataRealSize )
			setScale( M.fmin( w/frameData.realWid, (h==null?w:h)/frameData.realHei ) );
		else
			setScale( M.fmin( w/tile.width, (h==null?w:h)/tile.height ) );
	}

	public inline function setPivotCoord(x:Float, y:Float) {
		pivot.setCoord(x, y);
	}

	public inline function setCenterRatio(xRatio=0.5, yRatio=0.5) {
		pivot.setCenterRatio(xRatio, yRatio);
	}

	public inline function totalFrames() {
		return group.frames.length;
	}

	public inline function colorize(col:Col, ?alpha=1.0) {
		color.setColor( col.withAlpha(alpha) );
	}

	public inline function uncolorize() {
		color.set(1,1,1,1);
	}

	override function onAdd(){
		super.onAdd();

		destroyed = false;

		if( lib != null )
			lib.addChild( this );
	}

	override function onRemove() {
		super.onRemove();

		destroyed = true;

		if( lib!=null )
			lib.removeChild(this);

		disposeAnimManager();
	}


	override function getBoundsRec( relativeTo, out, forSize ) {
		super.getBoundsRec(relativeTo, out, forSize);
		addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}


	inline function get_tile() {
		if( customTile!=null ) {
			if( pivot.isUsingCoord() ) {
				customTile.dx = -Std.int(pivot.coordX);
				customTile.dy = -Std.int(pivot.coordY);
			}
			else if( pivot.isUsingFactor() ) {
				customTile.dx = -Std.int(customTile.width*pivot.centerFactorX);
				customTile.dy = -Std.int(customTile.height*pivot.centerFactorY);
			}
			return customTile;
		}
		else if( isReady() ) {
			final fd = frameData;
			rawTile.setPosition(fd.x, fd.y);
			rawTile.setSize(fd.wid, fd.hei);

			// Apply pivot
			if( pivot.isUsingCoord() ) {
				rawTile.dx = -Std.int(pivot.coordX + fd.realX);
				rawTile.dy = -Std.int(pivot.coordY + fd.realY);
			}
			else if( pivot.isUsingFactor() ) {
				rawTile.dx = -Std.int(fd.realWid*pivot.centerFactorX + fd.realX);
				rawTile.dy = -Std.int(fd.realHei*pivot.centerFactorY + fd.realY);
			}
			return rawTile;
		}
		else {
			if( pivot.isUsingCoord() ) {
				rawTile.dx = -Std.int(pivot.coordX);
				rawTile.dy = -Std.int(pivot.coordY);
			}
			else if( pivot.isUsingFactor() ) {
				rawTile.dx = -Std.int(rawTile.width*pivot.centerFactorX);
				rawTile.dy = -Std.int(rawTile.height*pivot.centerFactorY);
			}
			return rawTile;
		}
	}


	/**
		Skew the bottom and right sides by pixels distances.
		WARNING:
		1. if the HSprite scaleX/Y changes later, this method should be called again.
		2. This method is not compatible with rotation(s).
	**/
	public function skewPx(xPixels:Float, yPixels:Float) {
		skewX = Math.atan(xPixels/(tile.height*scaleY));
		skewY = Math.atan(yPixels/(tile.width*scaleX));
	}

	override function calcAbsPos() {
		super.calcAbsPos();

		if( skewX!=0 || skewY!=0 ) {
			matB += matA * Math.tan(skewY);
			matC += matD * Math.tan(skewX);
		}
	}


	override function draw( ctx : h2d.RenderContext ) {
		emitTile(ctx, tile);
	}

	override function sync(ctx:h2d.RenderContext) {
		super.sync(ctx);
		if( animAllocated )
			anim.update( Game.ME.tmod );
	}

	public function changeVisible(v:Bool) {
		animVisibleFlag = v;
	}
}
