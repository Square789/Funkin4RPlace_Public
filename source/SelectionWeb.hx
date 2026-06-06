// Horrible piece of garbage overengineered thing for main menu

package;

import haxe.ValueException;


enum SelectionWebNodeDirection {
	SWND_LEFT;
	SWND_DOWN;
	SWND_RIGHT;
	SWND_UP;
}

// Dear garbage collector: Enjoy. -xoxo, Square
class SelectionWebNode {
	public var left:Null<SelectionWebNode>;
	public var right:Null<SelectionWebNode>;
	public var up:Null<SelectionWebNode>;
	public var down:Null<SelectionWebNode>;
	public var parent:SelectionWebNode;
	public var children:Array<SelectionWebNode>;
	public var index:Int;
	public var permeate:Bool;
	public var rollover:Bool;
	public var action:Int;
	public var id:Int;

	public var lastChild(get, never):Null<SelectionWebNode>;
	public var firstChild(get, never):Null<SelectionWebNode>;

	public function new(action:Int = -1, id:Int = -1, permeate:Bool = false, rollover:Bool = false) {
		this.left = null;
		this.right = null;
		this.up = null;
		this.down = null;
		this.action = action;
		this.parent = null;
		this.children = [];
		this.index = -1;
		// Permeating nodes are unselectable and will always select downwards when targeted
		this.permeate = permeate;
		// Rollover nodes are unselectable and will:
		// if going laterally, have the selection directed past themselves or
		// when targeted absolutely, select their left node instead.
		// Rollover takes precedence to permeation. Usable for inactive elements.
		this.rollover = rollover;
		this.id = id;
	}

	public function addChild(node:SelectionWebNode) {
		if (node.parent != null) {
			throw new ValueException(
				"Node already has a parent, too lazy to write relocation code cause that never happens."
			);
		}
		children.push(node);
		node.parent = this;
		node.index = children.length - 1;
	}

	public function insertChild(node:SelectionWebNode, idx:Int) {
		if (idx > children.length) {
			idx = children.length;
		}
		for (i in idx...children.length) {
			children[i].index += 1;
		}
		children.insert(idx, node);
		node.parent = this;
		node.index = idx;
	}

	public function linkChildrenHorizontal(loop:Bool = false) {
		for (i in 0...(children.length - 1)) {
			children[i].right = children[i + 1];
			children[i + 1].left = children[i];
		}
		if (loop && children.length > 1) {
			firstChild.left = lastChild;
			lastChild.right = firstChild;
		}
	}

	public function linkChildrenVertical(loop:Bool = false) {
		for (i in 0...(children.length - 1)) {
			children[i].down = children[i + 1];
			children[i + 1].up = children[i];
		}
		if (loop && children.length > 1) {
			firstChild.up = lastChild;
			lastChild.down = firstChild;
		}
	}

	public function linkLeft(other:SelectionWebNode, onlyWhenNull:Bool = false) {
		if (!onlyWhenNull || this.left == null) {
			this.left = other;
		}
		if (!onlyWhenNull || other.right == null) {
			other.right = this;
		}
	}

	public function linkRight(other:SelectionWebNode, onlyWhenNull:Bool = false) {
		other.linkLeft(this, onlyWhenNull);
	}

	public function linkUp(other:SelectionWebNode, onlyWhenNull:Bool = false) {
		if (!onlyWhenNull || this.up == null) {
			this.up = other;
		}
		if (!onlyWhenNull || other.down == null) {
			other.down = this;
		}
	}

	public function linkDown(other:SelectionWebNode, onlyWhenNull:Bool = false) {
		other.linkUp(this, onlyWhenNull);
	}

	public inline function get_firstChild() {
		return children[0];
	}
	public inline function get_lastChild() {
		return children[children.length - 1];
	}

	public function getLateralNodeAt(direction:SelectionWebNodeDirection):Null<SelectionWebNode> {
		return switch(direction) {
			case SWND_LEFT : left;
			case SWND_DOWN : down;
			case SWND_RIGHT: right;
			case SWND_UP:    up;
		};

	}
	public function getFirstLinkedDirection():Null<SelectionWebNodeDirection> {
		if (up != null) {
			return SWND_UP;
		}
		if (left != null) {
			return SWND_LEFT;
		}
		if (down != null) {
			return SWND_DOWN;
		}
		if (right != null) {
			return SWND_RIGHT;
		}
		return null;
	}

	public function isDirectionLinked(dir:SelectionWebNodeDirection) {
		return switch (dir) {
			case SWND_LEFT : left != null;
			case SWND_DOWN : down != null;
			case SWND_RIGHT: right != null;
			case SWND_UP:    up != null;
		}
	}
}

// Hmmm
// today i will overengineer
// (clueless)
class SelectionWebManager {
	public var selectionPath:Array<SelectionWebNode>;
	private var selectedNode:Null<SelectionWebNode>;

	public function new(initialNode:SelectionWebNode) {
		selectAbsolute(initialNode);
	}

	private function tryPermeate():Void {
		if (selectedNode.rollover) {
			var d = selectedNode.getFirstLinkedDirection();
			if (d != null) {
				selectLateral(d);
			}
			throw new ValueException("Rollover node had nowhere to roll over to.");
		}
		while (selectedNode.permeate) {
			if (!selectChild()) {
				throw new ValueException("Permeating node at end of selection web.");
			}
		}
	}

	public function selectAbsolute(node:SelectionWebNode):Bool {
		if (node == selectedNode) {
			// Warning: may permate to `selected` node later and return true
			// when actually the path hasn't changed.
			// I do not care enough to check for that.
			return false;
		}

		var hook = node;
		selectionPath = [node];
		while (hook.parent != null) {
			hook = hook.parent;
			selectionPath.push(hook);
		}
		selectionPath.reverse();
		selectedNode = node;
		tryPermeate();
		return true;
	}

	public function selectLateral(direction:SelectionWebNodeDirection):Bool {
		var newSelectedNode = selectedNode.getLateralNodeAt(direction);
		if (newSelectedNode == null) {
			return false;
		}
		while (newSelectedNode.rollover) {
			var d = newSelectedNode.isDirectionLinked(direction) ? direction : newSelectedNode.getFirstLinkedDirection();
			if (d == null) {
				return false;
			}
			newSelectedNode = newSelectedNode.getLateralNodeAt(d);
		}
		if (newSelectedNode.parent != selectedNode.parent) {
			return selectAbsolute(newSelectedNode);
		}

		selectedNode = newSelectedNode;
		selectionPath[selectionPath.length - 1] = newSelectedNode;
		tryPermeate();
		return true;
	}

	public function selectChild():Bool {
		if (selectedNode.children.length == 0) {
			return false;
		}
		selectedNode = selectedNode.children[0];
		selectionPath.push(selectedNode);
		tryPermeate();
		return true;
	}

	public function selectParent():Bool {
		if (selectionPath.length <= 1 || selectedNode.parent.permeate) {
			return false;
		}
		selectedNode = selectedNode.parent;
		selectionPath.pop();
		return true;
	}
}
