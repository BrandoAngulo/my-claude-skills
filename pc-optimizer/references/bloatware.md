# Software marcado por `software.ps1`

Los patrones viven en `scripts/software.ps1` (variable `$patrones`). Si cambias uno, cambia esta tabla también.

**Regla general:** que un programa aparezca aquí no significa "borrar". Significa "preguntar al usuario". Nunca desinstalar en bloque.

| Categoría | Severidad | Ejemplos | Qué hacer |
|---|---|---|---|
| `antivirus_prueba` | Media | McAfee, Norton, TotalAV, Avast Free, AVG Free, Avira | Confirmar si hay licencia paga. Si no, desinstalar: Windows Defender se reactiva solo. Si quedan restos, usar la herramienta de borrado del fabricante (McAfee MCPR, Norton Remove and Reinstall). |
| `optimizador` | Media | CCleaner, IObit (Advanced SystemCare, Driver Booster), Driver Easy, DriverPack, Restoro, Reimage, Fortect, Outbyte, Wise Care, Glary, Auslogics | Desinstalar. No aceleran nada medible, varios corren en segundo plano y algunos instalan software adicional o drivers incorrectos. |
| `utilidad_fabricante_pesada` | Baja | Armoury Crate, MSI Center, Dragon Center, OMEN Gaming Hub, Alienware Command Center, iCUE, NZXT CAM, Razer Synapse | **No desinstalar a ciegas**: pueden controlar ventiladores, perfiles de energía, límites de carga de batería o el teclado. Preguntar qué usa el usuario. Si solo es RGB, quitar del inicio. |
| `utilidad_soporte` | Info | Dell SupportAssist, HP Support Assistant, Lenovo Vantage, MyASUS, Acer Care Center | Útil para BIOS y drivers. Puede quitarse del inicio. |
| `promocional` | Baja | WildTangent, McAfee WebAdvisor, Norton Safe Web, navegadores "secure" de Avast/AVG, barras de herramientas | Desinstalar si el usuario no lo reconoce como propio. |
| Apps Store promo | Baja | Candy Crush, Disney+, TikTok, Facebook, Instagram, Prime Video, LinkedIn, Clipchamp | Desinstalar las que no use. Poco espacio; el beneficio es menos ruido. |

## Programas de inicio

- Deshabilitar desde **Administrador de tareas > Aplicaciones de arranque** o Configuración > Aplicaciones > Inicio. Deshabilitar no desinstala y se revierte con un clic.
- Candidatos típicos a deshabilitar: actualizadores (Adobe, Java, Google Update cuando hay tarea programada), launchers de juegos, clientes de chat que no se usan a diario, OneDrive si no se usa.
- **No** deshabilitar: drivers de audio/touchpad/gráficos (Realtek, Synaptics, ELAN, Intel Graphics Command Center si controla pantalla), software de VPN corporativa, agentes de TI de la empresa.

## Servicios

- El script solo lista servicios automáticos **fuera de `C:\Windows`** y **no firmados por Microsoft**.
- Nunca deshabilitar servicios de drivers (Intel, Realtek, NVIDIA, AMD, Synaptics) ni de seguridad/TI corporativa.
- Si un servicio pertenece a un programa marcado arriba, se resuelve desinstalando el programa, no deshabilitando el servicio.

## PC corporativo

En equipos de empresa, antivirus, agentes de inventario, VPN y herramientas de monitoreo son de TI: aparecen en el reporte pero se marcan como **no tocar** salvo que el usuario confirme que son suyos.
