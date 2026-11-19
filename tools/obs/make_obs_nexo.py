"""Gera a coleção de cenas 'NEXO Dual GPU' e o perfil 'NEXO Gravacao' do OBS.
Não altera a coleção nem o perfil existentes; faz backup do user.ini antes de trocar a seleção."""
import json, os, shutil, uuid, re, sys, datetime

OBS = os.path.join(os.environ["APPDATA"], "obs-studio")
W, H = 1920, 1080
CAP_W, CAP_H = 960, 600          # cada monitor 1440x900 em escala 2/3
CAP_Y = 240
PANEL_MON = r"<CAMINHO_DO_MONITOR_DO_PAINEL>"   # caminho DISPLAY#... do monitor ligado na GTX 750 Ti
GAME_MON = r"<CAMINHO_DO_MONITOR_DO_JOGO>"      # caminho DISPLAY#... do monitor ligado na GTX 970

def abgr(hexrgb):
    r, g, b = int(hexrgb[0:2], 16), int(hexrgb[2:4], 16), int(hexrgb[4:6], 16)
    return (0xFF << 24) | (b << 16) | (g << 8) | r

BASE = {"mixers": 0, "sync": 0, "flags": 0, "volume": 1.0, "balance": 0.5, "enabled": True, "muted": False,
        "push-to-mute": False, "push-to-mute-delay": 0, "push-to-talk": False, "push-to-talk-delay": 0,
        "hotkeys": {}, "deinterlace_mode": 0, "deinterlace_field_order": 0, "monitoring_type": 0,
        "monitoring_enabled": False, "private_settings": {}}

def source(name, sid, vid, settings):
    d = {"prev_ver": 553648129, "name": name, "uuid": str(uuid.uuid4()), "id": sid, "versioned_id": vid, "settings": settings}
    d.update(json.loads(json.dumps(BASE)))
    return d

def text(name, txt, size, color, bold=True):
    return source(name, "text_gdiplus", "text_gdiplus_v3", {
        "text": txt, "font": {"face": "Bahnschrift", "flags": 1 if bold else 0, "size": size, "style": "Bold" if bold else "Regular"},
        "color": abgr(color), "antialiasing": True})

sources = []
bg = source("Fundo", "color_source", "color_source_v3", {"color": abgr("242A32"), "width": W, "height": H}); sources.append(bg)
panel = source("Monitor do painel (GTX 750 Ti)", "monitor_capture", "monitor_capture", {"method": 2, "monitor_id": PANEL_MON, "force_sdr": True, "capture_cursor": True}); sources.append(panel)
game = source("Monitor do jogo (GTX 970)", "monitor_capture", "monitor_capture", {"method": 1, "monitor_id": GAME_MON, "force_sdr": True, "capture_cursor": False}); sources.append(game)
title = text("Título", "NEXO DUAL GPU LAB  ·  GTX 970 + GTX 750 Ti  ·  i7-3770K (2012)", 46, "E2E7EC"); sources.append(title)
capL = text("Legenda do painel", "NEXO GPU CONTROL  (monitor ligado na GTX 750 Ti)", 22, "8C97A4", bold=False); sources.append(capL)
capR = text("Legenda do jogo", "Tela principal / jogo  (monitor ligado na GTX 970)", 22, "8C97A4", bold=False); sources.append(capR)

steps = [
    ("1 · Só GTX 970", "Teste 1  ·  Só a GTX 970 trabalha", "F2A541"),
    ("2 · Só GTX 750 Ti", "Teste 2  ·  Só a GTX 750 Ti trabalha", "4FC1C9"),
    ("3 · Duas placas", "Teste 3  ·  As duas placas juntas (divisão medida ~72/28)", "E2E7EC"),
    ("4 · Forza Horizon 4", "Forza Horizon 4  ·  o jogo usa só a GTX 970; a GTX 750 Ti fica parada", "F2A541"),
]

def item(src, iid, x, y, sx=1.0, sy=1.0, ref=(W, H)):
    return {"name": src["name"], "source_uuid": src["uuid"], "visible": True, "locked": True, "rot": 0.0,
            "scale_ref": {"x": float(ref[0]), "y": float(ref[1])}, "align": 5, "bounds_type": 0, "bounds_align": 0,
            "bounds_crop": False, "crop_left": 0, "crop_top": 0, "crop_right": 0, "crop_bottom": 0, "id": iid,
            "group_item_backup": False, "pos": {"x": float(x), "y": float(y)}, "scale": {"x": sx, "y": sy},
            "bounds": {"x": 0.0, "y": 0.0}, "scale_filter": "disable", "blend_method": "default", "blend_type": "normal",
            "show_transition": {"duration": 300}, "hide_transition": {"duration": 300}, "private_settings": {}}

scenes = []
for name, label, color in steps:
    lab = text(f"Legenda: {name}", label, 40, color); sources.append(lab)
    s = 2 / 3
    items = [item(bg, 1, 0, 0), item(panel, 2, 0, CAP_Y, s, s), item(game, 3, CAP_W, CAP_Y, s, s),
             item(title, 4, 48, 70), item(capL, 5, 24, CAP_Y - 34), item(capR, 6, CAP_W + 24, CAP_Y - 34), item(lab, 7, 48, 880)]
    sc = source(name, "scene", "scene", {"id_counter": 7, "custom_size": False, "items": items})
    sc["canvas_uuid"] = "6c69626f-6273-4c00-9d88-c5136d61696e"
    scenes.append(sc)
sources = scenes + sources

collection = {
    "name": "NEXO Dual GPU", "sources": sources, "groups": [], "scene_order": [{"name": n} for n, _, _ in steps],
    "current_scene": steps[0][0], "current_program_scene": steps[0][0], "canvases": [], "current_transition": "Fade",
    "transition_duration": 300, "transitions": [], "quick_transitions": [], "saved_projectors": [], "preview_locked": False,
    "scaling_enabled": False, "scaling_level": 0, "scaling_off_x": 0.0, "scaling_off_y": 0.0, "virtual-camera": {"type2": 3},
    "modules": {}, "resolution": {"x": W, "y": H}, "version": 2,
}
# Copia os dispositivos de áudio da coleção atual (desktop e microfone), se existirem.
try:
    cur = json.load(open(os.path.join(OBS, "basic", "scenes", "Sem_nome.json"), encoding="utf-8"))
    for k in ("DesktopAudioDevice1", "AuxAudioDevice1"):
        if k in cur: collection[k] = cur[k]
except Exception as e:
    print("aviso: áudio não copiado:", e)

scene_path = os.path.join(OBS, "basic", "scenes", "NEXO_Dual_GPU.json")
json.dump(collection, open(scene_path, "w", encoding="utf-8"), ensure_ascii=False, indent=4)
print("coleção:", scene_path)

# Perfil novo a partir do atual
src_prof = os.path.join(OBS, "basic", "profiles", "Sem_nome")
dst_prof = os.path.join(OBS, "basic", "profiles", "NEXO_Gravacao")
if not os.path.exists(dst_prof):
    shutil.copytree(src_prof, dst_prof)
ini_path = os.path.join(dst_prof, "basic.ini")
ini = open(ini_path, encoding="utf-8-sig").read()
def setkey(text, section, key, value):
    pat = re.compile(r"(\[%s\][^\[]*?)^%s=.*?$" % (re.escape(section), re.escape(key)), re.M | re.S)
    if pat.search(text): return pat.sub(lambda m: m.group(1) + f"{key}={value}", text, count=1)
    return re.sub(r"(\[%s\]\s*\n)" % re.escape(section), lambda m: m.group(1) + f"{key}={value}\n", text, count=1)
for sec, k, v in [("General", "Name", "NEXO Gravacao"), ("Video", "BaseCX", "1920"), ("Video", "BaseCY", "1080"),
                  ("Video", "OutputCX", "1920"), ("Video", "OutputCY", "1080"), ("Video", "FPSType", "0"), ("Video", "FPSCommon", "60"),
                  ("SimpleOutput", "RecQuality", "HQ"), ("SimpleOutput", "RecEncoder", "nvenc"), ("SimpleOutput", "RecFormat2", "hybrid_mp4"),
                  ("Output", "FilenameFormatting", "NEXO %CCYY-%MM-%DD %hh-%mm-%ss")]:
    ini = setkey(ini, sec, k, v)
open(ini_path, "w", encoding="utf-8").write(ini)
print("perfil:", ini_path)

# Seleciona os novos (backup do user.ini)
user = os.path.join(OBS, "user.ini")
stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
shutil.copy2(user, user + f".bak-nexo-{stamp}")
u = open(user, encoding="utf-8-sig").read()
for k, v in [("Profile", "NEXO Gravacao"), ("ProfileDir", "NEXO_Gravacao"), ("SceneCollection", "NEXO Dual GPU"), ("SceneCollectionFile", "NEXO_Dual_GPU.json")]:
    u = re.sub(r"^%s=.*$" % k, f"{k}={v}", u, count=1, flags=re.M)
open(user, "w", encoding="utf-8").write(u)
print("user.ini atualizado; backup:", user + f".bak-nexo-{stamp}")
