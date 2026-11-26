// Coloca objetos decorativos (casetas del mercado, carteles, luces...) leidos de
// $profile:DayZKit\objetos.json. Cada objeto se pone a ras de suelo (SurfaceY) mas su
// "Altura", asi que solo hacen falta X y Z. No se guardan en la persistencia: se
// vuelven a crear en cada arranque.

class DayZKit_Objeto
{
	string Clase;
	float X;
	float Z;
	float Yaw;
	float Altura;
}

class DayZKit_ListaObjetos
{
	ref array<ref DayZKit_Objeto> Objetos;
}

modded class MissionServer
{
	override void OnInit()
	{
		super.OnInit();
		DayZKit_CrearObjetos();
	}

	void DayZKit_CrearObjetos()
	{
		string ruta = "$profile:DayZKit\\objetos.json";
		if (!FileExist(ruta))
			return;

		DayZKit_ListaObjetos lista = new DayZKit_ListaObjetos();
		string error;
		if (!JsonFileLoader<DayZKit_ListaObjetos>.LoadFile(ruta, lista, error))
		{
			Print("[DayZKit] No se pudo leer " + ruta + ": " + error);
			return;
		}
		if (!lista.Objetos)
			return;

		int creados = 0;
		foreach (DayZKit_Objeto o : lista.Objetos)
		{
			vector pos = Vector(o.X, GetGame().SurfaceY(o.X, o.Z) + o.Altura, o.Z);
			Object obj = GetGame().CreateObjectEx(o.Clase, pos, ECE_CREATEPHYSICS | ECE_NOLIFETIME | ECE_KEEPHEIGHT | ECE_NOPERSISTENCY_WORLD);
			if (!obj)
			{
				Print("[DayZKit] No se pudo crear " + o.Clase);
				continue;
			}
			obj.SetPosition(pos);
			obj.SetOrientation(Vector(o.Yaw, 0, 0));
			obj.Update();
			EntityAI ent = EntityAI.Cast(obj);
			if (ent)
				ent.SetAllowDamage(false);
			creados++;
		}
		Print("[DayZKit] Objetos del mercado creados: " + creados);
	}
}
