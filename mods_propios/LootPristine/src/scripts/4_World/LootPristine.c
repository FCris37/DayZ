// LootPristine: todo lo que genera la economia central (loot del suelo, de zombis,
// de contenedores, piezas de coches...) aparece en estado perfecto (Pristine).
// Solo se ejecuta en el servidor. Se carga con -serverMod, los jugadores no lo necesitan.

modded class ItemBase
{
	override void EEOnCECreate()
	{
		super.EEOnCECreate();
		if (!GetGame().IsServer())
			return;
		SetHealthMax("", "");
		// Por si la economia aplica el desgaste despues de crear el objeto
		GetGame().GetCallQueue(CALL_CATEGORY_SYSTEM).CallLater(LootPristine_Reparar, 2000, false);
	}

	void LootPristine_Reparar()
	{
		SetHealthMax("", "");
	}
}

modded class Weapon_Base
{
	override void EEOnCECreate()
	{
		super.EEOnCECreate();
		if (!GetGame().IsServer())
			return;
		SetHealthMax("", "");
		GetGame().GetCallQueue(CALL_CATEGORY_SYSTEM).CallLater(LootPristine_Reparar, 2000, false);
	}

	void LootPristine_Reparar()
	{
		SetHealthMax("", "");
	}
}
