#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape, unescape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    KeepTogether,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents

RAIZ = Path(__file__).resolve().parent
FUENTE = RAIZ / "manual.md"
SALIDA = RAIZ / "manual.pdf"
ANCHO, ALTO = A4
MARGEN = 1.9 * cm
ANCHO_CONTENIDO = ANCHO - 2 * MARGEN

FUENTES = [
    ("OLSans", "OLSans-Bold", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf", "Helvetica", "Helvetica-Bold"),
    ("OLMono", "OLMono-Bold", "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf", "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono-Bold.ttf", "Courier", "Courier-Bold"),
]


def registrar_fuentes() -> dict[str, str]:
    nombres: dict[str, str] = {}
    for regular, negrita, ruta_regular, ruta_negrita, respaldo, respaldo_negrita in FUENTES:
        if Path(ruta_regular).exists() and Path(ruta_negrita).exists():
            pdfmetrics.registerFont(TTFont(regular, ruta_regular))
            pdfmetrics.registerFont(TTFont(negrita, ruta_negrita))
            nombres[regular] = regular
            nombres[negrita] = negrita
        else:
            nombres[regular] = respaldo
            nombres[negrita] = respaldo_negrita
    return nombres


FONT = registrar_fuentes()
REG = FONT["OLSans"]
NEGRITA = FONT["OLSans-Bold"]
MONO = FONT["OLMono"]
MONO_NEG = FONT["OLMono-Bold"]

AZUL = colors.HexColor("#143A52")
AZUL_MEDIO = colors.HexColor("#1F6F8B")
ACENTO = colors.HexColor("#2CA6A4")
FONDO = colors.HexColor("#F7F9FB")
FONDO_CODIGO = colors.HexColor("#F1F5F8")
BORDE = colors.HexColor("#DCE4EA")
TEXTO = colors.HexColor("#22313F")
GRIS = colors.HexColor("#5C6B77")
VERDE = colors.HexColor("#2F855A")
AMBAR = colors.HexColor("#B7791F")
ROJO = colors.HexColor("#C53030")
BLANCO = colors.white


def css(color: colors.Color) -> str:
    return "#" + color.hexval()[2:]


ETIQUETAS = {
    "nota": AZUL_MEDIO,
    "consejo": VERDE,
    "comprueba": ACENTO,
    "verificación": VERDE,
    "importante": AMBAR,
    "advertencia": ROJO,
}


def crear_estilos() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()["BodyText"]
    estilos: dict[str, ParagraphStyle] = {}

    def crear(nombre: str, **kwargs) -> ParagraphStyle:
        valores = {"fontName": REG, "textColor": TEXTO}
        valores.update(kwargs)
        return ParagraphStyle(nombre, parent=base, **valores)

    estilos["kicker"] = crear(
        "CoverKicker", fontName=NEGRITA, fontSize=9.5, leading=13,
        textColor=ACENTO, alignment=TA_CENTER, spaceAfter=8,
    )
    estilos["titulo"] = crear(
        "CoverTitle", fontName=NEGRITA, fontSize=25, leading=30,
        textColor=AZUL, alignment=TA_CENTER, spaceAfter=8,
    )
    estilos["subtitulo"] = crear(
        "CoverSubtitle", fontSize=13, leading=18,
        textColor=AZUL_MEDIO, alignment=TA_CENTER, spaceAfter=4,
    )
    estilos["bajada"] = crear(
        "CoverLead", fontSize=10.5, leading=16,
        textColor=GRIS, alignment=TA_CENTER, spaceBefore=6,
    )
    estilos["meta"] = crear(
        "CoverMeta", fontSize=8, leading=12,
        textColor=GRIS, alignment=TA_CENTER, spaceBefore=10,
    )
    estilos["tarjeta_titulo"] = crear(
        "CardTitle", fontName=NEGRITA, fontSize=9.5, leading=13,
        textColor=AZUL, alignment=TA_CENTER,
    )
    estilos["tarjeta_texto"] = crear(
        "CardText", fontSize=8, leading=11.5,
        textColor=GRIS, alignment=TA_CENTER,
    )
    estilos["h1"] = crear(
        "Heading1", fontName=NEGRITA, fontSize=15, leading=19,
        textColor=AZUL, spaceBefore=16, spaceAfter=8, keepWithNext=1,
    )
    estilos["h2"] = crear(
        "Heading2", fontName=NEGRITA, fontSize=11.4, leading=15,
        textColor=AZUL_MEDIO, spaceBefore=12, spaceAfter=5, keepWithNext=1,
    )
    estilos["h3"] = crear(
        "Heading3", fontName=NEGRITA, fontSize=10, leading=14,
        textColor=AZUL_MEDIO, spaceBefore=9, spaceAfter=4, keepWithNext=1,
    )
    estilos["cuerpo"] = crear("Body", fontSize=9.5, leading=14, spaceAfter=6)
    estilos["lista"] = crear(
        "Bullet", fontSize=9.3, leading=13.4, leftIndent=14,
        bulletIndent=3, bulletFontName=NEGRITA, spaceAfter=2,
    )
    estilos["tarea"] = crear(
        "Task", fontSize=9.3, leading=13.4, leftIndent=18,
        bulletFontName=MONO, bulletFontSize=8.2, bulletIndent=2, spaceAfter=2,
    )
    estilos["codigo"] = crear(
        "Code", fontName=MONO, fontSize=8, leading=11.6, textColor=TEXTO,
    )
    estilos["tabla"] = crear("TableCell", fontSize=8.2, leading=11.4)
    estilos["tabla_cabecera"] = crear(
        "TableHead", fontName=NEGRITA, fontSize=8.3, leading=11.4, textColor=BLANCO,
    )
    estilos["llamada"] = crear("Callout", fontSize=9.2, leading=13.2)
    estilos["pie"] = crear("Caption", fontSize=8, leading=11, textColor=GRIS)
    estilos["paso"] = crear(
        "Step", fontName=NEGRITA, fontSize=10, leading=13,
        textColor=BLANCO, alignment=TA_CENTER,
    )
    estilos["flujo"] = crear("Flow", fontSize=8.8, leading=12.5)
    estilos["indice_titulo"] = crear(
        "TocTitle", fontName=NEGRITA, fontSize=15, leading=19,
        textColor=AZUL, spaceAfter=10,
    )
    return estilos


ETIQUETA_HTML = re.compile(r"<[^>]+>")
TAREA = re.compile(r"^\[([ xX])\]\s+")


def limpiar(texto: str) -> str:
    return unescape(ETIQUETA_HTML.sub("", texto)).strip()


def en_linea(texto: str) -> str:
    resultado = escape(texto)
    resultado = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", resultado)
    resultado = re.sub(
        r"`([^`]+)`",
        rf'<font face="{MONO}" color="{css(AZUL_MEDIO)}">\1</font>',
        resultado,
    )
    resultado = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        rf'<link href="\2" color="{css(AZUL_MEDIO)}"><u>\1</u></link>',
        resultado,
    )
    return resultado


def bloque_codigo(lineas: list[str], estilos: dict[str, ParagraphStyle]):
    if any("muestra/csv" in linea for linea in lineas) and any("etl/01_bronze.py" in linea for linea in lineas):
        return diagrama_flujo(estilos)

    partes = []
    for linea in lineas:
        texto = escape(linea.expandtabs(4))
        texto = texto.replace(" ", "&nbsp;")
        color = css(GRIS) if texto.lstrip().startswith("#") else css(TEXTO)
        partes.append(f'<font color="{color}">{texto}</font>')
    parrafo = Paragraph("<br/>".join(partes), estilos["codigo"])
    tabla = Table([[parrafo]], colWidths=[ANCHO_CONTENIDO], hAlign="LEFT")
    tabla.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), FONDO_CODIGO),
        ("BOX", (0, 0), (-1, -1), 0.6, BORDE),
        ("LINEBEFORE", (0, 0), (0, -1), 3, ACENTO),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 2), tabla, Spacer(1, 7)])


def diagrama_flujo(estilos: dict[str, ParagraphStyle]):
    etapas = [
        ("01", "Origen", "muestra/csv/*.csv · cinco CSV de ejemplo"),
        ("02", "Bronze", "etl/01_bronze.py · copia exacta + SHA-256"),
        ("03", "Silver", "etl/02_silver.py · validación y rechazos"),
        ("04", "Gold", "etl/03_gold.py · dimensiones, hechos y resumen"),
        ("05", "HDFS", "hdfs/cargar_gold.sh · /medallion/gold/fecha=FECHA/"),
        ("06", "PostgreSQL", "postgres/cargar_gold.py · esquema estrella"),
        ("07", "SQL", "psql · consultas y EXPLAIN ANALYZE"),
    ]
    filas = []
    for numero, nombre, detalle in etapas:
        filas.append([
            Paragraph(numero, estilos["paso"]),
            Paragraph(f"<b>{nombre}</b><br/>{escape(detalle)}", estilos["flujo"]),
        ])
    tabla = Table(filas, colWidths=[1.25 * cm, ANCHO_CONTENIDO - 1.25 * cm], hAlign="LEFT")
    estilo = [
        ("BACKGROUND", (0, 0), (0, -1), AZUL),
        ("ROWBACKGROUNDS", (1, 0), (1, -1), [BLANCO, FONDO]),
        ("LINEBELOW", (0, 0), (-1, -2), 0.5, BORDE),
        ("BOX", (0, 0), (-1, -1), 0.6, BORDE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    tabla.setStyle(TableStyle(estilo))
    return KeepTogether([
        Paragraph("Ruta de datos de extremo a extremo", estilos["pie"]),
        Spacer(1, 3),
        tabla,
        Spacer(1, 7),
    ])


def celdas_fila(linea: str) -> list[str]:
    return [parte.strip() for parte in linea.strip().strip("|").split("|")]


def tabla_markdown(filas: list[str], estilos: dict[str, ParagraphStyle]):
    datos = []
    for indice, linea in enumerate(filas):
        celdas = celdas_fila(linea)
        estilo = estilos["tabla_cabecera"] if indice == 0 else estilos["tabla"]
        datos.append([Paragraph(en_linea(celda), estilo) for celda in celdas])
    ancho = ANCHO_CONTENIDO / len(datos[0])
    tabla = Table(
        datos,
        colWidths=[ancho] * len(datos[0]),
        repeatRows=1,
        hAlign="LEFT",
    )
    tabla.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), AZUL),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [BLANCO, FONDO]),
        ("LINEBELOW", (0, 0), (-1, -1), 0.4, BORDE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return KeepTogether([Spacer(1, 2), tabla, Spacer(1, 8)])


def llamada(lineas: list[str], estilos: dict[str, ParagraphStyle]):
    texto = " ".join(linea.lstrip(">").strip() for linea in lineas)
    coincidencia = re.match(r"^\*\*([^*]+):\*\*\s*(.*)$", texto)
    if coincidencia:
        etiqueta, resto = coincidencia.groups()
        color = ETIQUETAS.get(etiqueta.lower().strip(), AZUL_MEDIO)
        contenido = (
            f'<b><font color="{css(color)}">{escape(etiqueta)}:</font></b> '
            f"{en_linea(resto)}"
        )
    else:
        color = AZUL_MEDIO
        contenido = en_linea(texto)
    parrafo = Paragraph(contenido, estilos["llamada"])
    tabla = Table([[parrafo]], colWidths=[ANCHO_CONTENIDO], hAlign="LEFT")
    tabla.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), FONDO),
        ("LINEBEFORE", (0, 0), (0, -1), 3, color),
        ("BOX", (0, 0), (-1, -1), 0.5, BORDE),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 2), tabla, Spacer(1, 6)])


def convertir_markdown(texto: str, estilos: dict[str, ParagraphStyle]) -> list:
    lineas = texto.splitlines()
    resultado: list = []
    parrafo: list[str] = []
    indice = 0

    def vaciar_parrafo() -> None:
        if parrafo:
            resultado.append(Paragraph(en_linea(" ".join(parrafo)), estilos["cuerpo"]))
            parrafo.clear()

    while indice < len(lineas):
        cruda = lineas[indice].rstrip()
        linea = cruda.strip()

        if not linea:
            vaciar_parrafo()
            indice += 1
            continue

        if linea.startswith("```"):
            vaciar_parrafo()
            indice += 1
            bloque: list[str] = []
            while indice < len(lineas) and not lineas[indice].strip().startswith("```"):
                bloque.append(lineas[indice])
                indice += 1
            indice += 1
            resultado.append(bloque_codigo(bloque, estilos))
            continue

        if cruda.startswith("    ") or cruda.startswith("\t"):
            vaciar_parrafo()
            bloque = []
            while indice < len(lineas) and (
                lineas[indice].startswith("    ") or lineas[indice].startswith("\t")
            ):
                bloque.append(lineas[indice].expandtabs(4)[4:])
                indice += 1
            resultado.append(bloque_codigo(bloque, estilos))
            continue

        cabecera = re.match(r"^(#{1,6})\s+(.*)$", linea)
        if cabecera:
            vaciar_parrafo()
            nivel = len(cabecera.group(1))
            if nivel > 1:
                clave = {2: "h1", 3: "h2"}.get(nivel, "h3")
                resultado.append(Paragraph(en_linea(cabecera.group(2)), estilos[clave]))
            indice += 1
            continue

        if linea.startswith("|") and indice + 1 < len(lineas):
            siguiente = celdas_fila(lineas[indice + 1])
            if siguiente and all(re.fullmatch(r":?-{3,}:?", celda) for celda in siguiente):
                vaciar_parrafo()
                filas_tabla = [linea]
                indice += 2
                while indice < len(lineas) and lineas[indice].strip().startswith("|"):
                    filas_tabla.append(lineas[indice].strip())
                    indice += 1
                resultado.append(tabla_markdown(filas_tabla, estilos))
                continue

        if linea.startswith(">"):
            vaciar_parrafo()
            notas: list[str] = []
            while indice < len(lineas) and lineas[indice].strip().startswith(">"):
                notas.append(lineas[indice].strip())
                indice += 1
            resultado.append(llamada(notas, estilos))
            continue

        viñeta = re.match(r"^[-*]\s+(.*)$", linea)
        if viñeta:
            vaciar_parrafo()
            while indice < len(lineas):
                actual = re.match(r"^[-*]\s+(.*)$", lineas[indice].strip())
                if not actual:
                    break
                contenido = actual.group(1)
                tarea = TAREA.match(contenido)
                if tarea:
                    marca = "[x]" if tarea.group(1).lower() == "x" else "[ ]"
                    resultado.append(
                        Paragraph(
                            en_linea(TAREA.sub("", contenido)),
                            estilos["tarea"],
                            bulletText=marca,
                        )
                    )
                else:
                    resultado.append(
                        Paragraph(en_linea(contenido), estilos["lista"], bulletText="•")
                    )
                indice += 1
            continue

        numerada = re.match(r"^(\d+)\.\s+(.*)$", linea)
        if numerada:
            vaciar_parrafo()
            while indice < len(lineas):
                actual = re.match(r"^(\d+)\.\s+(.*)$", lineas[indice].strip())
                if not actual:
                    break
                resultado.append(
                    Paragraph(
                        en_linea(actual.group(2)),
                        estilos["lista"],
                        bulletText=actual.group(1) + ".",
                    )
                )
                indice += 1
            continue

        if re.fullmatch(r"-{3,}|\*{3,}", linea):
            vaciar_parrafo()
            resultado.append(HRFlowable(width="100%", thickness=0.6, color=BORDE, spaceBefore=4, spaceAfter=8))
            indice += 1
            continue

        parrafo.append(linea)
        indice += 1

    vaciar_parrafo()
    return resultado


def dibujar_portada(canvas, doc) -> None:
    canvas.saveState()
    canvas.setTitle("Manual de ejecución - Big Data Open Library")
    canvas.setAuthor("Proyecto Big Data Open Library")
    canvas.setFillColor(AZUL)
    canvas.rect(0, ALTO - 4.9 * cm, ANCHO, 4.9 * cm, stroke=0, fill=1)
    canvas.setFillColor(ACENTO)
    canvas.rect(0, ALTO - 4.9 * cm - 3, ANCHO, 3, stroke=0, fill=1)
    canvas.setFillColor(BLANCO)
    canvas.setFont(NEGRITA, 9)
    canvas.drawString(MARGEN, ALTO - 1.5 * cm, "EDICIÓN DOCENTE · BIG DATA")
    canvas.restoreState()


def dibujar_cuerpo(canvas, doc) -> None:
    canvas.saveState()
    canvas.setTitle("Manual de ejecución - Big Data Open Library")
    canvas.setFont(NEGRITA, 7.6)
    canvas.setFillColor(AZUL)
    canvas.drawString(MARGEN, ALTO - 1.05 * cm, "BIG DATA · OPEN LIBRARY")
    canvas.setFont(REG, 7.6)
    canvas.setFillColor(GRIS)
    canvas.drawRightString(ANCHO - MARGEN, ALTO - 1.05 * cm, "Manual de ejecución")
    canvas.setStrokeColor(BORDE)
    canvas.setLineWidth(0.6)
    canvas.line(MARGEN, ALTO - 1.25 * cm, ANCHO - MARGEN, ALTO - 1.25 * cm)
    canvas.line(MARGEN, 1.25 * cm, ANCHO - MARGEN, 1.25 * cm)
    canvas.setFont(REG, 7.6)
    canvas.drawString(MARGEN, 0.85 * cm, "ETL medallion · HDFS · PostgreSQL · SQL")
    canvas.drawRightString(ANCHO - MARGEN, 0.85 * cm, f"Página {doc.page}")
    canvas.restoreState()


def crear_plantillas() -> list[PageTemplate]:
    portada = Frame(
        0, 0, ANCHO, ALTO, id="portada",
        leftPadding=MARGEN, rightPadding=MARGEN,
        topPadding=5.4 * cm, bottomPadding=1.7 * cm,
    )
    cuerpo = Frame(
        MARGEN, 1.55 * cm, ANCHO_CONTENIDO, ALTO - 3.05 * cm, id="cuerpo",
        leftPadding=0, rightPadding=0, topPadding=0.25 * cm, bottomPadding=0,
    )
    return [
        PageTemplate(id="portada", frames=[portada], onPage=dibujar_portada),
        PageTemplate(id="cuerpo", frames=[cuerpo], onPage=dibujar_cuerpo),
    ]


def tarjetas_portada(estilos: dict[str, ParagraphStyle]) -> Table:
    datos = [
        [
            Paragraph("MEDALLION", estilos["tarjeta_titulo"]),
            Paragraph("HDFS", estilos["tarjeta_titulo"]),
            Paragraph("POSTGRESQL", estilos["tarjeta_titulo"]),
        ],
        [
            Paragraph("CSV verificados", estilos["tarjeta_texto"]),
            Paragraph("Gold particionado", estilos["tarjeta_texto"]),
            Paragraph("Estrella consultable", estilos["tarjeta_texto"]),
        ],
    ]
    ancho = ANCHO_CONTENIDO / 3
    tabla = Table(datos, colWidths=[ancho] * 3, hAlign="CENTER")
    tabla.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), FONDO),
        ("BOX", (0, 0), (-1, -1), 0.8, BORDE),
        ("INNERGRID", (0, 0), (-1, -1), 0.5, BORDE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, 0), 11),
        ("BOTTOMPADDING", (0, 1), (-1, 1), 11),
        ("TOPPADDING", (0, 1), (-1, 1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 2),
    ]))
    return tabla


def crear_indice() -> TableOfContents:
    indice = TableOfContents()
    indice.levelStyles = [
        ParagraphStyle(
            "toc0", fontName=NEGRITA, fontSize=9.4, leading=16,
            leftIndent=8, firstLineIndent=-8, textColor=AZUL, spaceBefore=5,
        ),
        ParagraphStyle(
            "toc1", fontName=REG, fontSize=8.6, leading=13,
            leftIndent=20, firstLineIndent=-10, textColor=GRIS,
        ),
        ParagraphStyle(
            "toc2", fontName=REG, fontSize=8.1, leading=12,
            leftIndent=30, firstLineIndent=-12, textColor=GRIS,
        ),
    ]
    return indice


def construir_historia(estilos: dict[str, ParagraphStyle], indice: TableOfContents) -> list:
    historia = [
        Spacer(1, 0.2 * cm),
        Paragraph("GUÍA PARA ESTUDIANTES · EDICIÓN 2026", estilos["kicker"]),
        Paragraph("Manual de ejecución", estilos["titulo"]),
        Paragraph("Big Data con Open Library", estilos["subtitulo"]),
        Paragraph("Arquitectura Medallion · HDFS · PostgreSQL · SQL", estilos["subtitulo"]),
        HRFlowable(width="42%", thickness=2, color=ACENTO, hAlign="CENTER", spaceBefore=12, spaceAfter=14),
        tarjetas_portada(estilos),
        Paragraph(
            "Ejecuta cada fase a mano, verifica su salida y entiende qué está ocurriendo en cada capa.",
            estilos["bajada"],
        ),
        Paragraph("Fuente: manual/manual.md · Generado con bash manual/generar_pdf.sh", estilos["meta"]),
        NextPageTemplate("cuerpo"),
        PageBreak(),
        Paragraph("Contenido", estilos["indice_titulo"]),
        indice,
        Spacer(1, 8),
        HRFlowable(width="100%", thickness=0.6, color=BORDE),
        Spacer(1, 10),
    ]
    historia.extend(convertir_markdown(FUENTE.read_text(encoding="utf-8"), estilos))
    return historia


def construir_documento(destino: Path, indice: TableOfContents) -> BaseDocTemplate:
    documento = BaseDocTemplate(
        str(destino),
        pagesize=A4,
        leftMargin=MARGEN,
        rightMargin=MARGEN,
        topMargin=MARGEN,
        bottomMargin=MARGEN,
        title="Manual de ejecución - Big Data Open Library",
        author="Proyecto Big Data Open Library",
        pageTemplates=crear_plantillas(),
    )
    def despues(flowable) -> None:
        if not isinstance(flowable, Paragraph):
            return
        niveles = {"Heading1": 0, "Heading2": 1, "Heading3": 2}
        nivel = niveles.get(flowable.style.name)
        if nivel is None:
            return
        texto = limpiar(flowable.text)
        clave = f"sec-{len(indice._entries) + 1}"
        documento.canv.bookmarkPage(clave)
        documento.canv.addOutlineEntry(texto, clave, level=nivel, closed=False)
        documento.notify("TOCEntry", (nivel, texto, documento.page, clave))

    documento.afterFlowable = despues
    return documento


def main() -> None:
    if not FUENTE.exists():
        sys.exit(f"No existe {FUENTE}")
    estilos = crear_estilos()
    indice = crear_indice()
    documento = construir_documento(SALIDA, indice)
    documento.multiBuild(construir_historia(estilos, indice), maxPasses=4)
    print(f"PDF generado: {SALIDA} ({SALIDA.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
