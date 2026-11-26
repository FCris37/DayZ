"""Empaqueta src/ en @DayZKit/addons/DayZKit.pbo (formato PBO sin comprimir).
Uso: python empaquetar_pbo.py"""
import hashlib, os, struct

AQUI = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(AQUI, 'src')
SALIDA = os.path.join(AQUI, '..', '@DayZKit', 'addons', 'DayZKit.pbo')
PREFIJO = 'DayZKit'

archivos = []
for raiz, _, nombres in os.walk(SRC):
    for n in sorted(nombres):
        ruta = os.path.join(raiz, n)
        rel = os.path.relpath(ruta, SRC).replace('/', '\\')
        with open(ruta, 'rb') as f:
            archivos.append((rel, f.read()))
archivos.sort()

out = bytearray()
# Cabecera de extension ('Vers') con el prefijo
out += b'\0' + struct.pack('<5I', 0x56657273, 0, 0, 0, 0)
out += b'prefix\0' + PREFIJO.encode() + b'\0' + b'\0'
for rel, datos in archivos:
    out += rel.encode() + b'\0' + struct.pack('<5I', 0, len(datos), 0, 0, len(datos))
out += b'\0' + struct.pack('<5I', 0, 0, 0, 0, 0)
for _, datos in archivos:
    out += datos
out += b'\0' + hashlib.sha1(bytes(out)).digest()

os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
with open(SALIDA, 'wb') as f:
    f.write(out)
print('OK', os.path.normpath(SALIDA), len(out), 'bytes,', len(archivos), 'archivos')
