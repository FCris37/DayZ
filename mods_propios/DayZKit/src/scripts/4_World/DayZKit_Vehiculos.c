// Vehiculos indestructibles (opcional, se activa desde $profile:DayZKit\ajustes.json):
// no reciben dano de choques, disparos ni explosiones, ni sus piezas montadas (ruedas, puertas,
// cristales, bateria...). El agua SI les sigue afectando: el juego quita vida al motor sumergido
// con AddHealth, que no pasa por el sistema de dano que se desactiva aqui.
// Vale para coches, y para helicopteros y barcas de Expansion (heredan de CarScript).

class DayZKit_Ajustes
{
	bool VehiculosIndestructibles;

	static ref DayZKit_Ajustes s_Instancia;

	static DayZKit_Ajustes Get()
	{
		if (!s_Instancia)
		{
			s_Instancia = new DayZKit_Ajustes();
			string ruta = "$profile:DayZKit\\ajustes.json";
			if (FileExist(ruta))
			{
				string error;
				if (!JsonFileLoader<DayZKit_Ajustes>.LoadFile(ruta, s_Instancia, error))
					Print("[DayZKit] No se pudo leer " + ruta + ": " + error);
			}
		}
		return s_Instancia;
	}
}

modded class CarScript
{
	override void EEInit()
	{
		super.EEInit();
		if (GetGame().IsServer() && DayZKit_Ajustes.Get().VehiculosIndestructibles)
			GetGame().GetCallQueue(CALL_CATEGORY_SYSTEM).CallLater(DayZKit_HacerIndestructible, 1000, false);
	}

	void DayZKit_HacerIndestructible()
	{
		SetAllowDamage(false);
		int n = GetInventory().AttachmentCount();
		for (int i = 0; i < n; i++)
		{
			EntityAI pieza = GetInventory().GetAttachmentFromIndex(i);
			if (pieza)
				pieza.SetAllowDamage(false);
		}
	}

	override void EEItemAttached(EntityAI item, string slot_name)
	{
		super.EEItemAttached(item, slot_name);
		if (item && GetGame().IsServer() && DayZKit_Ajustes.Get().VehiculosIndestructibles)
			item.SetAllowDamage(false);
	}

	override void EEItemDetached(EntityAI item, string slot_name)
	{
		super.EEItemDetached(item, slot_name);
		if (item && GetGame().IsServer() && DayZKit_Ajustes.Get().VehiculosIndestructibles)
			item.SetAllowDamage(true);
	}
}
