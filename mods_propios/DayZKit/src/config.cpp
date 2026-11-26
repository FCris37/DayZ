class CfgPatches
{
	class DayZKit
	{
		units[] = {};
		weapons[] = {};
		requiredVersion = 0.1;
		requiredAddons[] = {"DZ_Data", "DZ_Scripts"};
	};
};

class CfgMods
{
	class DayZKit
	{
		dir = "DayZKit";
		name = "DayZKit";
		author = "DayZKit";
		version = "1.1";
		type = "mod";
		hideName = 1;
		hidePicture = 1;
		dependencies[] = {"World", "Mission"};
		class defs
		{
			class worldScriptModule
			{
				value = "";
				files[] = {"DayZKit/scripts/4_World"};
			};
			class missionScriptModule
			{
				value = "";
				files[] = {"DayZKit/scripts/5_Mission"};
			};
		};
	};
};
