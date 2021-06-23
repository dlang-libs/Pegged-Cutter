module pegged.cutter;

import pegged.grammar;

@safe:

void optimize(TParseTree)(ref TParseTree p, string[] force = null, string[] keep = null)
{
	import std.algorithm : canFind, endsWith, startsWith;
	import std.string : indexOf;

	if (p.children.length == 0)
		return;
	bool processed = true;
	while (processed)
	{
		processed = false;
		ParseTree[] new_children;
		foreach (ref child; p.children)
		{
			if (force !is null && force.canFind(child.name))
			{
			}
			else if (keep !is null && keep.canFind(child.name))
			{
				new_children ~= child;
				continue;
			}
			else if (child.children.length != 1)
			{
				new_children ~= child;
				continue;
			}
			foreach (ref grand_child; child.children)
			{
				new_children ~= grand_child;
			}
			processed = true;
		}
		p.children = new_children;
	}
	foreach (ref child; p.children)
	{
		optimize!TParseTree(child, force, keep);
	}
}

void cutNodes(TParseTree)(ref TParseTree p, string[] names1 = null, string[] names2 = null)
{
	import std.algorithm : canFind, endsWith, startsWith;
	import std.string : indexOf;

	if (p.name.endsWith(`_`))
	{
		p.matches.length = 0;
		p.name = p.name[0 .. $ - 1];
	}
	else if (names2 !is null && names2.canFind(p.name))
	{
		p.matches.length = 0;
	}
	if (p.children.length == 0)
		return;
	bool processed = true;
	while (processed)
	{
		processed = false;
		ParseTree[] new_children;
		foreach (ref child; p.children)
		{
			if (child.name == "any")
			{
			}
			else if (child.name.canFind('!'))
			{
			}
			else if (names1 !is null && names1.canFind(child.name))
			{
			}
			else if (child.name.indexOf("._") == -1)
			{
				new_children ~= child;
				continue;
			}
			foreach (ref grand_child; child.children)
			{
				new_children ~= grand_child;
			}
			processed = true;
		}
		p.children = new_children;
	}
	foreach (ref child; p.children)
	{
		cutNodes!TParseTree(child, names1, names2);
	}
}
