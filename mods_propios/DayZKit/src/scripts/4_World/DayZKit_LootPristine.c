// Loot siempre en perfecto estado: todo lo que crea la economia central (loot del suelo,
// de zombis, de contenedores, piezas de coches, armas...) aparece Pristine.
// Weapon_Base hereda de ItemBase, asi que esto cubre tambien las armas.

modded class ItemBase
{
	override void EEOnCECreate()
	{
		super.EEOnCECreate();
		if (!GetGame().IsServer())
			return;
		SetHealthMax("", "");
		// Por si la economia aplica el desgaste despues de crear el objeto
		GetGame().GetCallQueue(CALL_CATEGORY_SYSTEM).CallLater(DayZKit_Reparar, 2000, false);
	}

	void DayZKit_Reparar()
	{
		SetHealthMax("", "");
	}
}
