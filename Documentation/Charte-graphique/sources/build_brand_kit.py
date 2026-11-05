"""Build the Walkuno reference PDF and portable Orbelio embed kit.

Uses only repository artwork, system fonts, reportlab and Pillow.
Run with the bundled Codex Python or a Python with reportlab and Pillow.
"""
from pathlib import Path
import json
import math
import re
import shutil
import xml.etree.ElementTree as ET
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'Documentation/Charte-graphique'
KIT = BASE / 'kit-web'
ASSETS = KIT / 'assets'
PDF = ROOT / 'output/pdf/Walkuno-charte-graphique.pdf'
ASSETS.mkdir(parents=True, exist_ok=True)
PDF.parent.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'Documentation/Identite/Cadence/02-Grande-foulee.svg'
original = SOURCE.read_text()
svg = ET.fromstring(original)
NS = '{http://www.w3.org/2000/svg}'
rear = [el.attrib['d'] for el in svg.find(NS+'g')]
front = svg.find(NS+'path').attrib['d']

C = dict(ink='#0A242C', electric='#A3FF70', teal='#31B99F',
         light='#EFF6F1', card='#13353C', green='#37651C',
         lightTeal='#006758', white='#FFFFFF')

for name, fg, bg in [('sombre', C['electric'], C['teal']),
                     ('clair', C['green'], C['lightTeal']),
                     ('encre', C['ink'], C['ink']),
                     ('blanc', C['white'], C['white'])]:
    content = original[original.index('  <g fill='):original.rindex('</svg>')]
    content = content.replace('#A3FF70', fg).replace('#31B99F', bg)
    (ASSETS / f'walkuno-symbole-{name}.svg').write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="16 16 224 208" role="img" aria-labelledby="title">\n'
        f'<title id="title">Walkuno - symbole sur fond {name}</title>\n'+content+'</svg>\n')
shutil.copy2(SOURCE, ASSETS/'walkuno-icone.svg')
for size in [1024, 512, 192]:
    with Image.open(ROOT/'Walkuno/Assets.xcassets/AppIcon.appiconset/Icon.png') as im:
        im.resize((size,size), Image.Resampling.LANCZOS).save(ASSETS/f'walkuno-icone-{size}.png')

def lum(h):
    rgb = [int(h[i:i+2],16)/255 for i in (1,3,5)]
    return sum(w*(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4)
               for w,c in zip([.2126,.7152,.0722],rgb))
def contrast(a,b):
    x,y=sorted([lum(a),lum(b)])
    return (y+.05)/(x+.05)

tokens = {'name':'Walkuno', 'version':'2026-11-05', 'colorSpace':'sRGB',
          'source':'AppShared/Design.swift / WalkunoStyle', 'colors':C,
          'webRecommendations':{'cardRadius':26,'buttonRadius':999,'spacingUnit':8,
             'fontStack':'ui-rounded, "SF Pro Rounded", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'}}
(KIT/'walkuno-tokens.json').write_text(json.dumps(tokens, ensure_ascii=False, indent=2)+'\n')

ring = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 480" role="img" aria-labelledby="t d">
<title id="t">Illustration de progression Walkuno</title>
<desc id="d">Exemple fictif : 6 432 pas sur un objectif de 8 000 pas, soit 80 pour cent.</desc>
<defs><linearGradient id="g" x1="1" y1="0" x2="0" y2="1"><stop stop-color="#A3FF70"/><stop offset="1" stop-color="#31B99F"/></linearGradient></defs>
<circle cx="240" cy="240" r="190" fill="#13353C"/>
<circle cx="240" cy="240" r="170" fill="none" stroke="#244B43" stroke-width="22"/>
<circle cx="240" cy="240" r="170" fill="none" stroke="url(#g)" stroke-width="22" stroke-linecap="round" stroke-dasharray="855 1068" transform="rotate(-90 240 240)"/>
<circle cx="240" cy="240" r="141" fill="none" stroke="#31B99F" stroke-opacity=".45" stroke-dasharray="1 10"/>
<g text-anchor="middle" font-family="ui-rounded, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif">
<text x="240" y="185" font-size="18" font-weight="600" fill="#A3FF70">AUJOURD’HUI</text>
<text x="240" y="263" font-size="74" font-weight="700" letter-spacing="-3" fill="white">6 432</text>
<text x="240" y="300" font-size="18" fill="#D8E8DD">sur 8 000 pas</text>
<rect x="201" y="322" width="78" height="34" rx="17" fill="#A3FF70"/>
<text x="240" y="346" font-size="18" font-weight="700" fill="#0A242C">80 %</text></g></svg>'''
(ASSETS/'walkuno-progression.svg').write_text(ring+'\n')

css = '''/* Walkuno / Orbelio - styles confines au composant, sans police distante. */
.walkuno-embed { container-type: inline-size; }
.walkuno-feature {
  --walkuno-ink:#0A242C; --walkuno-electric:#A3FF70;
  --walkuno-teal:#31B99F; --walkuno-surface:#13353C;
  box-sizing:border-box; display:grid; grid-template-columns:minmax(0,1.15fr) minmax(0,.85fr);
  align-items:center; gap:32px; padding:clamp(24px,5vw,64px);
  border-radius:26px; background:var(--walkuno-ink); color:#fff;
  font-family:ui-rounded,"SF Pro Rounded",-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}
.walkuno-feature *, .walkuno-feature *::before, .walkuno-feature *::after { box-sizing:border-box; }
.walkuno-feature__brand { display:flex; gap:12px; align-items:center; color:var(--walkuno-electric); }
.walkuno-feature__mark { display:block; width:40px; height:40px; object-fit:contain; }
.walkuno-feature__name { font-size:28px; line-height:1.1; font-weight:750; letter-spacing:-.6px; }
.walkuno-feature__eyebrow { margin:24px 0 12px; color:var(--walkuno-teal); font-size:12px; line-height:1.6; font-weight:650; letter-spacing:1.5px; text-transform:uppercase; }
.walkuno-feature__title { margin:0; max-width:13ch; color:#fff; font-size:clamp(32px,4.2vw,56px); font-weight:750; letter-spacing:-1.7px; line-height:1.06; }
.walkuno-feature__description { margin:20px 0 0; max-width:42ch; color:#D8E8DD; font-size:17px; line-height:1.6; }
.walkuno-feature__benefits { display:flex; flex-wrap:wrap; gap:8px; list-style:none; margin:24px 0; padding:0; }
.walkuno-feature__benefits li { margin:0; padding:7px 12px; border:1px solid #52716F; border-radius:999px; font-size:12px; line-height:1.5; color:#D8E8DD; }
.walkuno-feature__cta { display:inline-flex; align-items:center; justify-content:center; min-height:48px; padding:12px 22px; border:2px solid transparent; border-radius:999px; background:var(--walkuno-electric); color:var(--walkuno-ink); font-size:15px; line-height:1.4; font-weight:750; text-decoration:none; }
.walkuno-feature__cta:hover { text-decoration:underline; text-underline-offset:4px; }
.walkuno-feature__cta:focus-visible { outline:3px solid white; outline-offset:5px; }
.walkuno-feature__platforms { margin:14px 0 0; color:#D8E8DD; font-size:12px; line-height:1.6; }
.walkuno-feature__visual { min-width:0; margin:0; text-align:center; }
.walkuno-feature__ring { display:block; width:100%; max-width:400px; height:auto; margin:auto; }
.walkuno-feature__caption { margin:8px 0 0; color:#D8E8DD; font-size:11px; line-height:1.6; }
@container (max-width:700px) {
  .walkuno-feature { grid-template-columns:minmax(0,1fr); gap:24px; padding:28px; }
  .walkuno-feature__title { font-size:40px; }
  .walkuno-feature__ring { max-width:300px; }
}
@media (max-width:600px) {
  .walkuno-feature { grid-template-columns:minmax(0,1fr); gap:24px; padding:24px; }
  .walkuno-feature__title { font-size:36px; letter-spacing:-1px; }
  .walkuno-feature__ring { max-width:280px; }
}
'''
(KIT/'walkuno-encart.css').write_text(css)

fragment='''<div class="walkuno-embed">
  <section class="walkuno-feature" aria-labelledby="walkuno-title">
    <div class="walkuno-feature__content">
      <div class="walkuno-feature__brand">
        <img class="walkuno-feature__mark" src="assets/walkuno-symbole-sombre.svg" alt="" width="40" height="40">
        <span class="walkuno-feature__name">Walkuno</span>
      </div>
      <p class="walkuno-feature__eyebrow">Une application Orbelio</p>
      <h2 class="walkuno-feature__title" id="walkuno-title">Chaque pas compte.</h2>
      <p class="walkuno-feature__description">Vos pas, vos objectifs et vos progrès, en un regard. Walkuno vous accompagne au quotidien sur iPhone et Apple Watch.</p>
      <ul class="walkuno-feature__benefits" aria-label="Les atouts de Walkuno">
        <li>Sans compte</li><li>Sans publicité</li><li>Widgets</li>
      </ul>
      <!-- Dans Orbelio, remplacer cette ancre de démonstration par la vraie page Walkuno. -->
      <a class="walkuno-feature__cta" href="#walkuno-details">Découvrir Walkuno <span aria-hidden="true">&nbsp;↗</span></a>
      <p class="walkuno-feature__platforms">Pour iPhone et Apple Watch</p>
    </div>
    <figure class="walkuno-feature__visual">
      <img class="walkuno-feature__ring" src="assets/walkuno-progression.svg" width="480" height="480" alt="Exemple de progression : 6 432 pas sur un objectif de 8 000, soit 80 %.">
      <figcaption class="walkuno-feature__caption">Illustration de progression · données fictives</figcaption>
    </figure>
  </section>
</div>'''
(KIT/'encart.html').write_text(fragment+'\n')
(KIT/'index.html').write_text('''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Walkuno · Proposition d’encart Orbelio</title><link rel="stylesheet" href="walkuno-encart.css">
<style>body{margin:0;background:#EFF6F1;color:#0A242C;font-family:system-ui,sans-serif}main{max-width:1200px;margin:auto;padding:40px 24px}.preview-note{font-size:13px;margin:0 0 24px;color:#37651C}.preview-details{max-width:720px;margin:48px 0;line-height:1.7}.preview-details h2{line-height:1.2}a{color:#006758}@media(max-width:600px){main{padding:24px 12px}}</style>
</head><body><main><p class="preview-note">Proposition de composant pour Orbelio · Walkuno · 05.11.2026</p>'''+fragment+'''
<section class="preview-details" id="walkuno-details" tabindex="-1"><h2>Votre activité, à votre rythme.</h2>
<p>Consultez vos pas, fixez votre objectif quotidien et suivez vos progrès grâce aux statistiques, aux succès et aux widgets. Walkuno s’appuie sur Apple Santé et propose une application compagnon Apple Watch.</p>
<p>Sans compte et sans publicité. Les mesures de santé restent sur vos appareils. Certaines fonctions sont proposées avec Walkuno Premium.</p>
<p>Cette page est un aperçu local du composant. Le lien de découverte mène ici à une présentation de démonstration. Pour Orbelio, utilisez l’URL réelle de la page Walkuno. Le visuel est une illustration, pas une capture de l’application.</p></section>
</main></body></html>\n''')

(KIT/'LIRE-MOI.txt').write_text('''WALKUNO / KIT POUR ORBELIO / 05.11.2026

1. APERÇU
Ouvrir index.html dans un navigateur. Le composant s’adapte à la largeur de
son conteneur. Il peut aussi être consulté sans serveur ni connexion.
Les aperçus PNG livrés montrent le composant sur ordinateur et mobile.

2. INTÉGRATION
Copier le contenu de encart.html dans la page Orbelio et charger
walkuno-encart.css. Copier assets/ et ajuster les chemins si nécessaire.
Remplacer href="#walkuno-details" par la véritable URL de la page Walkuno.
Cette ancre fonctionne dans index.html ; elle n’est pas une URL publique.
Si plusieurs encarts coexistent, donner à chacun un id de titre unique
et adapter aria-labelledby. Choisir le niveau de titre adapté à la page.
Le CSS est limité aux classes walkuno-* ; aucun script ni police distante.

3. TYPOGRAPHIE
L’application utilise la police système Apple, arrondie pour son nom,
ses titres majeurs et ses compteurs. Sur le Web, ui-rounded puis les polices
système servent de repli. Le rendu varie selon l’appareil. Aucune police
Apple n’est fournie ni chargée comme webfont. Le PDF emploie Arial Rounded
pour illustrer les proportions ; ce n’est pas un logotype typographique figé.
Pour le mot Walkuno, garder la capitale W et le reste en minuscules.

4. IDENTITÉ
Le marcheur est extrait sans modification des tracés de
Documentation/Identite/Cadence/02-Grande-foulee.svg.
Version sombre : vert #A3FF70 et turquoise #31B99F sur encre #0A242C.
Version claire : vert #37651C et turquoise #006758 sur #EFF6F1 ou blanc.
Les versions encre et blanc sont monochromes, à utiliser si nécessaire.
L’icône carrée reprend exactement l’icône iOS actuelle, sans coins prédécoupés.
Taille minimale recommandée : symbole 24 px de haut ; icône 48 px.
Espace libre recommandé : 1/4 de la hauteur visible du symbole.
Ne pas déformer, incliner, recadrer, ajouter d’ombre ou de contour au symbole.

5. TEXTES ET PUBLICATION
Accroche : Chaque pas compte.
Texte : Vos pas, vos objectifs et vos progrès, en un regard. Walkuno vous
accompagne au quotidien sur iPhone et Apple Watch.
Atouts : Sans compte / Sans publicité / Widgets.
CTA : Découvrir Walkuno.
Mention éditeur : Une application Orbelio.
Ne pas annoncer une disponibilité App Store ou un prix sans les avoir validés.
Le kit n’invente ni lien App Store ni badge de téléchargement.
Certaines fonctions de l’application sont Premium ; ne pas présenter
l’ensemble de l’offre comme entièrement gratuit.

6. VISUEL
walkuno-progression.svg est une illustration de progression, pas une capture.
Les valeurs 6 432 / 8 000 / 80 % sont fictives. Garder la légende visible.
Les captures du dépôt ne sont pas reprises : elles montrent une version
antérieure de l’interface. Produire de nouvelles captures si nécessaire.

7. PÉRIMÈTRE
Charte tirée du code local consulté le 05.11.2026. Couleurs et tracés :
AppShared/Design.swift ; Scripts/generate_icon.swift ; icône iOS actuelle.
Texte éditorial : Documentation/AppStore.md, README.md et fonctions du projet.
Les dimensions Web, la composition et les variantes monochromes sont des
recommandations pour Orbelio. Le site Orbelio existant n’a pas été modifié
ni audité. Adapter les espacements à sa grille lors de l’intégration.
Les fontes utilisées pour produire le PDF ne sont pas redistribuées.
''')

# PDF: landscape visual reference, with all measurements in points.
FONTDIR=Path('/System/Library/Fonts/Supplemental')
for name,file in [('Body','Arial.ttf'),('Bold','Arial Bold.ttf'),('Round','Arial Rounded Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name,str(FONTDIR/file)))
pdfmetrics.registerFontFamily('Body', normal='Body', bold='Bold', italic='Body', boldItalic='Bold')
W,H=960,640
c=canvas.Canvas(str(PDF),pagesize=(W,H))
c.setTitle('Walkuno - Charte graphique et kit Orbelio')
c.setAuthor('Orbelio')
c.setSubject('Identité issue de l’application et recommandations pour son encart Web')

def col(v): return HexColor(C.get(v,v))
def rect(x,y,w,h,fill,r=0,stroke=None):
    c.setFillColor(col(fill)); c.setStrokeColor(col(stroke or fill))
    c.roundRect(x,H-y-h,w,h,r,fill=1,stroke=bool(stroke))
def text(x,y,s,size=12,color='ink',font='Body'):
    c.setFillColor(col(color));c.setFont(font,size);c.drawString(x,H-y-size*.8,s)
def para(x,y,s,width=390,size=13,color='ink',leading=None,font='Body'):
    style=ParagraphStyle('p',fontName=font,fontSize=size,leading=leading or size*1.5,textColor=col(color))
    p=Paragraph(s,style);_,h=p.wrap(width,500);p.drawOn(c,x,H-y-h);return h
def line(x,y,x2,y2,color='teal',width=1):
    c.setStrokeColor(col(color));c.setLineWidth(width);c.line(x,H-y,x2,H-y2)
def page(n,title,dark=False):
    rect(0,0,W,H,'ink' if dark else 'light')
    fg='electric' if dark else 'green'
    text(44,28,'WALKUNO  /  ORBELIO',10,fg,'Bold')
    text(44,72,title,32,'white' if dark else 'ink','Round')
    line(44,590,916,590,'card' if dark else '#CBDCCE')
    text(44,606,'CHARTE GRAPHIQUE  ·  05.11.2026',9,'teal' if dark else 'lightTeal')
    text(812,606,f'RÉFÉRENCE  /  0{n}',9,'teal' if dark else 'lightTeal')
def finish(): c.showPage()

def svgpath(d):
    toks=re.findall(r'[A-Za-z]|-?\d+(?:\.\d+)?',d);i=0;cmd=None;x=y=0;p=c.beginPath()
    while i<len(toks):
        if toks[i].isalpha():cmd=toks[i];i+=1
        if cmd=='Z':p.close();cmd=None;continue
        if cmd in ('M','L'):
            x,y=map(float,toks[i:i+2]);i+=2
            (p.moveTo if cmd=='M' else p.lineTo)(x,y)
            if cmd=='M':cmd='L'
        elif cmd=='Q':
            qx,qy,nx,ny=map(float,toks[i:i+4]);i+=4
            p.curveTo(x+2/3*(qx-x),y+2/3*(qy-y),nx+2/3*(qx-nx),ny+2/3*(qy-ny),nx,ny);x,y=nx,ny
        elif cmd is not None:raise ValueError(cmd)
    return p
def mark(x,y,size,light=False,mono=None):
    c.saveState();c.translate(x,H-y-size);c.scale(size/256,-size/256);c.translate(0,-256)
    c.setFillColor(col(mono or ('lightTeal' if light else 'teal')))
    for d in rear:c.drawPath(svgpath(d),fill=1,stroke=0)
    c.setFillColor(col(mono or ('green' if light else 'electric')))
    c.drawPath(svgpath(front),fill=1,stroke=0);c.circle(146,46,15,fill=1,stroke=0);c.restoreState()
def brand(x,y,size=32,light=False):
    mark(x,y,size,light);text(x+size+8,y+size*.22,'Walkuno',size*.62,'green' if light else 'electric','Round')
def ring(x,y,size):
    # Same visual vocabulary as the SVG illustration, without claiming a screen capture.
    cx=x+size/2;cy=H-y-size/2;r=size*.39
    c.setFillColor(col('card'));c.circle(cx,cy,size*.455,fill=1,stroke=0)
    c.setStrokeColor(col('#244B43'));c.setLineWidth(size*.05);c.circle(cx,cy,r,fill=0,stroke=1)
    c.setLineCap(1)
    for i in range(100):
        a=math.pi/2-2*math.pi*.8*i/100;b=math.pi/2-2*math.pi*.8*(i+1)/100
        t=i/99
        start=[163,255,112];end=[49,185,159]
        rgb=[(v*(1-t)+w*t)/255 for v,w in zip(start,end)]
        c.setStrokeColorRGB(*rgb);c.line(cx+r*math.cos(a),cy+r*math.sin(a),cx+r*math.cos(b),cy+r*math.sin(b))
    for label,dy,fs,color,font in [('AUJOURD’HUI',-.20,.043,'electric','Bold'),('6 432',.015,.165,'white','Round'),('sur 8 000 pas',.14,.043,'#D8E8DD','Body')]:
        c.setFont(font,size*fs);c.setFillColor(col(color));c.drawCentredString(cx,cy-size*dy,label)
    c.setFillColor(col('electric'));c.roundRect(cx-size*.09,cy-size*.285,size*.18,size*.08,size*.04,fill=1,stroke=0)
    c.setFont('Bold',size*.043);c.setFillColor(col('ink'));c.drawCentredString(cx,cy-size*.26,'80 %')
    c.setLineCap(0)
def pill(x,y,label,fill='electric',fg='ink',w=None):
    width=w or pdfmetrics.stringWidth(label,'Bold',11)+28
    rect(x,y,width,30,fill,15);text(x+14,y+10,label,11,fg,'Bold');return width

# 01 / Cover
page(1,'',True)
brand(44,105,58)
text(44,212,'Chaque pas',52,'white','Round')
text(44,273,'compte.',52,'electric','Round')
para(46,359,'Charte graphique de l’application<br/>et kit de présentation pour Orbelio.',420,19,'#D8E8DD',28)
text(46,451,'SIMPLE  /  VIVANT  /  ENCOURAGEANT',10,'teal','Bold')
para(46,490,'Une identité tirée du produit actuel.<br/>Des recommandations prêtes pour le Web.',390,12,'#D8E8DD')
ring(530,117,390)
text(606,521,'Illustration · données fictives',10,'#D8E8DD')
finish()

# 02 / Logo
page(2,'Le marcheur, signature de Walkuno.')
para(44,118,'Le symbole « Grande foulée » et les couleurs reprennent l’icône actuellement intégrée à l’application.',840,13)
rect(44,170,425,190,'ink',26);brand(76,221,105)
text(72,327,'VERSION POUR FOND SOMBRE',10,'teal','Bold')
rect(489,170,427,190,'white',26);brand(521,221,105,True)
text(517,327,'VERSION POUR FOND CLAIR',10,'lightTeal','Bold')
text(44,392,'Proportions et respiration',17,'ink','Round')
para(44,425,'Préserver les tracés et les deux couleurs. Réserver autour du symbole un espace libre égal à 1/4 de sa hauteur visible.',393,12)
para(44,492,'Minimum conseillé : symbole 24 px de haut ; icône 48 px. Garder le nom lisible et écrire <b>Walkuno</b>, avec une capitale W.',393,12)
text(489,392,'Applications',17,'ink','Round')
mark(486,424,65,mono='ink');mark(565,424,65,True)
rect(653,424,64,64,'ink',14);mark(653,424,64,mono='white')
para(489,508,'Les versions monochromes sont des adaptations Web. Ne pas étirer, incliner, recadrer ni ajouter de contour au marcheur.',413,12)
finish()

# 03 / Color
page(3,'Une énergie verte, sur une base encre.')
para(44,118,'Palette sRGB extraite de WalkunoStyle. Les variantes foncées assurent la lisibilité sur les surfaces claires.',850,13)
swatches=[('Encre','ink','Fond sombre / texte sur vert'),('Vert électrique','electric','Accent / bouton / progression'),('Turquoise','teal','Accent secondaire'),('Brume','light','Fond clair')]
for i,(label,key,role) in enumerate(swatches):
    x=44+i*223
    rect(x,174,203,100,key,18,stroke='#CBDCCE' if key=='light' else None)
    text(x,291,label,16,'ink','Bold');text(x,319,C[key],14,'lightTeal','Bold')
    para(x,345,role,202,11)
for i,(label,key) in enumerate([('Carte sombre','card'),('Texte vert sur clair','green'),('Texte turquoise sur clair','lightTeal')]):
    x=44+i*297;rect(x,409,42,42,key,10);text(x+54,411,label,12,'ink','Bold');text(x+54,433,C[key],11,'lightTeal')
rect(44,478,872,83,'white',18)
text(62,495,'ASSOCIATIONS POUR LE TEXTE',10,'lightTeal','Bold')
text(62,519,f"Vert / encre : {contrast(C['electric'],C['ink']):.2f}:1",12,'ink','Bold')
text(307,519,f"Blanc / encre : {contrast(C['white'],C['ink']):.2f}:1",12,'ink','Bold')
text(560,519,f"Vert foncé / brume : {contrast(C['green'],C['light']):.2f}:1",12,'ink','Bold')
text(62,542,'Ne pas utiliser le vert électrique comme texte sur blanc. Bouton vert : libellé encre.',11,'ink')
finish()

# 04 / type
page(4,'Des formes douces. Des chiffres lisibles.')
text(44,130,'TYPOGRAPHIE DU PRODUIT',10,'lightTeal','Bold')
text(44,160,'Walkuno',45,'ink','Round')
para(44,222,'Police système Apple. Dessin arrondi pour le nom, les grands titres et les compteurs ; dessin système standard pour le texte courant.',395,13)
text(44,320,'TRANSPOSITION WEB RECOMMANDÉE',10,'lightTeal','Bold')
para(44,350,'ui-rounded, « SF Pro Rounded », -apple-system, BlinkMacSystemFont, « Segoe UI », sans-serif.',395,13,font='Bold')
para(44,425,'Utiliser les polices présentes sur l’appareil. Aucun fichier de police Apple à distribuer. Dans ce PDF, Arial Rounded illustre les proportions : ce n’est pas un logotype figé.',395,12)
rect(489,130,427,231,'ink',26)
text(515,154,'Chaque pas compte.',28,'white','Round')
text(515,209,'6 432',61,'electric','Round')
text(519,284,'sur 8 000 pas',15,'#D8E8DD')
pill(519,315,'Découvrir Walkuno')
text(489,394,'Échelle Web',17,'ink','Round')
para(489,426,'Titre : 32 à 56 px, gras, interligne 1,06.<br/>Texte : 16 à 18 px, interligne 1,5 à 1,6.<br/>Bouton : 15 px, gras, hauteur minimum 48 px.',413,12)
para(489,506,'Cartes : rayon 26 px et marge interne 24 à 64 px.<br/>Pastilles et boutons : forme capsule.<br/>Rythme : multiples de 8 px ; ombres discrètes.',413,12)
finish()

# 05 / embed
page(5,'Un encart qui donne envie d’avancer.')
para(44,118,'Proposition de composition pour Orbelio. Le composant HTML/CSS livré est responsive et autonome.',850,13)
rect(44,163,610,302,'ink',26)
brand(70,189,31)
text(70,240,'UNE APPLICATION ORBELIO',8,'teal','Bold')
text(70,264,'Chaque pas',29,'white','Round');text(70,296,'compte.',29,'white','Round')
para(70,341,'Vos pas, vos objectifs et vos progrès,<br/>en un regard.',290,11,'#D8E8DD')
pill(70,400,'Découvrir Walkuno')
ring(394,217,230)
text(424,439,'Illustration · données fictives',7,'#D8E8DD')
rect(680,163,236,388,'ink',26)
brand(702,185,24)
text(702,225,'Chaque pas',24,'white','Round');text(702,252,'compte.',24,'white','Round')
para(702,289,'Vos pas, vos objectifs et vos<br/>progrès, en un regard.',189,10,'#D8E8DD')
pill(702,335,'Découvrir Walkuno')
ring(716,371,164)
text(708,535,'Illustration · données fictives',7,'#D8E8DD')
text(44,486,'Ordinateur',14,'ink','Round')
para(44,513,'Texte à gauche, illustration à droite. Sur mobile : texte, action puis visuel. L’encre et le vert créent un repère Walkuno au sein de la page Orbelio.',598,12)
text(681,566,'Mobile : une seule colonne',10,'lightTeal')
finish()

# 06 / handoff
page(6,'Les éléments à reprendre sur Orbelio.')
text(44,131,'TEXTE PRÊT À L’EMPLOI',10,'lightTeal','Bold')
text(44,166,'Chaque pas compte.',29,'ink','Round')
para(44,216,'Vos pas, vos objectifs et vos progrès, en un regard. Walkuno vous accompagne au quotidien sur iPhone et Apple Watch.',404,16,leading=24)
para(44,326,'<b>Atouts</b> : Sans compte · Sans publicité · Widgets.<br/><b>Action</b> : Découvrir Walkuno.<br/><b>Signature</b> : Une application Orbelio.',404,13,leading=23)
rect(44,431,414,126,'white',20)
para(62,449,'Ton simple, encourageant et sans injonction. Mettre les progrès du quotidien au premier plan. Ne pas annoncer de prix ni de disponibilité sans validation. Certaines fonctions sont Premium.',376,12)
text(494,131,'CONTENU DU KIT WEB',10,'lightTeal','Bold')
items=[('index.html','Aperçu local complet de l’encart.'),('encart.html + walkuno-encart.css','Fragment à intégrer et styles isolés.'),('assets/','Symboles SVG, icônes PNG et illustration.'),('walkuno-tokens.json','Couleurs et recommandations de styles.'),('LIRE-MOI.txt','Consignes, sources et lien à renseigner.')]
for i,(name,desc) in enumerate(items):
    y=166+i*57;text(494,y,name,12,'ink','Bold');text(494,y+21,desc,11,'lightTeal')
para(494,471,'<b>À l’intégration :</b> remplacer l’ancre de démonstration par la vraie page Walkuno. Le site Orbelio n’a pas été modifié. Les aperçus sont des illustrations, pas des captures de l’application.',418,11)
para(44,570,'Sources : AppShared/Design.swift · icône iOS · 02-Grande-foulee.svg · Documentation/AppStore.md. Mise en page Web : proposition.',872,8)
finish()
c.save()
print(f'Created {PDF} (6 pages) and {KIT}')
