class CfgPatches
{
	class LootPristine
	{
		units[] = {};
		weapons[] = {};
		requiredVersion = 0.1;
		requiredAddons[] = {"DZ_Data", "DZ_Scripts"};
	};
};

class CfgMods
{
	class LootPristine
	{
		dir = "LootPristine";
		name = "LootPristine";
		author = "DayZKit";
		version = "1.0";
		type = "mod";
		hideName = 1;
		hidePicture = 1;
		dependencies[] = {"World"};
		class defs
		{
			class worldScriptModule
			{
				value = "";
				files[] = {"LootPristine/scripts/4_World"};
			};
		};
	};
};
