# ChanSort Mac

Ein inoffizieller, nativer macOS-Port des GPLv3-Senderlisteneditors [ChanSort](https://github.com/PredatH0r/ChanSort).

**Herausgeber und Maintainer:** Thomas Meroth, Meroth IT-Service — https://www.pcffm.de  
**Originales ChanSort:** Horst Beham (`PredatH0r`) und Mitwirkende  
**Lizenz:** GNU General Public License Version 3 ausschließlich (`GPL-3.0-only`)  
**Sprachen:** englische Basisoberfläche; automatische deutsche Lokalisierung

ChanSort Mac ist ein unabhängiger Fork und keine offizielle Veröffentlichung des Originalautors oder eines Geräteherstellers. Herstellernamen dienen ausschließlich der sachlichen Bezeichnung kompatibler Exportformate. Einzelheiten stehen in [TRADEMARKS.md](TRADEMARKS.md).

## Funktionen

- TV-Senderlisten öffnen, durchsuchen, umbenennen, neu nummerieren und speichern.
- Stabile native macOS-Tabelle mit feststehender Kopfzeile, anpassbaren Spalten und Mehrfachauswahl.
- Ein- und Zwei-Listen-Modus, Drag & Drop, Zielplatz, Tauschen und alphabetische Sortierung.
- TV-, Radio-, Daten- und Favoritenlisten sowie geräteabhängige Optionen.
- Löschen/Wiederherstellen, Favoriten A–H, Sperren, Überspringen und Verstecken, soweit das Format dies unterstützt.
- Undo/Redo und automatische Sicherung vor dem Überschreiben eines Originalexports.
- Englische Basissprache und automatische deutsche Oberfläche bei deutscher macOS-Sprache.
- Native SwiftUI-Oberfläche ohne Wine, VM, DevExpress oder die originale Windows-Forms-Oberfläche.
- In-App-Bereich „Über & Rechtliches“ mit Copyright, Quellcode, GPL, Gewährleistungsausschluss, Bibliotheken und Markenhinweisen.

Neben M3U/M3U8, Enigma2, VDR, CSV und TSV kompiliert das mitgelieferte .NET-Backend die 25 plattformneutralen Loader aus ChanSort 2025-03-08. „Unterstützt“ bedeutet, dass ein Format von diesem Loaderstand erkannt wird; nicht jede Modell-, Firmware- oder künftige verschlüsselte Variante kann garantiert werden.

## Bauen

Voraussetzungen sind macOS 13 oder neuer, Xcode/Apple Command Line Tools mit Swift 5.9 oder neuer und .NET SDK 8.

```bash
./build-app.sh
```

Das Skript erzeugt gemeinsam unter `dist/`:

```text
ChanSort-Mac-<version>-arm64.zip
ChanSort-Mac-<version>-Source.zip
SHA256SUMS.txt
```

Tests und Compliance-Prüfung:

```bash
swift test --disable-sandbox
./scripts/check-compliance.sh
./scripts/audit-release.sh
```

Der lokale Standardbuild ist ad hoc signiert und nicht notarisiert. Für eine Produktionsveröffentlichung kann `CODESIGN_IDENTITY` auf ein eigenes Developer-ID-Application-Zertifikat gesetzt und das Ergebnis anschließend notarisiert werden.

## Lizenz und Veröffentlichung

Das Gesamtwerk wird ausschließlich unter GNU GPL Version 3 veröffentlicht. Der Lizenztext steht in [LICENSE](LICENSE). Herkunft und Urheber sind in [COPYRIGHT.md](COPYRIGHT.md), [AUTHORS.md](AUTHORS.md), [NOTICE.md](NOTICE.md) und [UPSTREAM.md](UPSTREAM.md) dokumentiert.

Jede Binärveröffentlichung muss am selben Downloadort und ohne Zusatzkosten zusammen mit dem exakt passenden Quellarchiv angeboten werden. [SOURCE-CODE.md](SOURCE-CODE.md) und [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) beschreiben den Ablauf.

Alle ermittelten Bibliotheken, Versionen, Urheber und Lizenzen stehen in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Die erforderlichen Lizenztexte werden auch in das App-Bundle aufgenommen.

Soweit gesetzlich zulässig, besteht keine Gewährleistung. Kommerzieller Vertrieb und bezahlter Support sind erlaubt; Empfänger behalten sämtliche Rechte der GPL zum Prüfen, Ändern und Weitergeben.

## Datenschutz und Sicherheit

Die App verarbeitet Senderlisten lokal. Diese Version enthält keine von ChanSort Mac implementierte Analyse, Werbung, Kontopflicht oder Telemetrie. Einzelheiten stehen in [PRIVACY.md](PRIVACY.md). Sicherheits- und Datenverlustmeldungen können über https://www.pcffm.de eingereicht werden.
