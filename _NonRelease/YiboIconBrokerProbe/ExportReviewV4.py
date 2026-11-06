"""Export the approved simplified group for temporary client validation."""
from pathlib import Path
import ExportTransparent as exporter

exporter.SOURCE = Path('C:/Users/Administrator/.codex/generated_images/01a13542-984b-75d1-a79b-41af5db0dd60/exec-4470a7e8-e208-489a-be56-11acfd781264.png')
exporter.MEDIA_NAME = 'MediaReviewV4'
exporter.OVERVIEW_NAME = 'ReviewV4Overview.png'
exporter.PREVIEW_NAME = 'ReviewV4NativeSizePreview.png'
exporter.MANIFEST_NAME = 'ReviewV4Manifest.json'
exporter.SQUARE_CROP = True
if __name__ == '__main__':
    exporter.main()
