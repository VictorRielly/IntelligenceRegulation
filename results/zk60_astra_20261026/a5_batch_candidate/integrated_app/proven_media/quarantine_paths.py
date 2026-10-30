"""Never expose quarantined batch receipts through publication or downloads."""
from pathlib import Path


def require_public_receipt_path(path):
    path = Path(path)
    for candidate in (path.absolute(), path.resolve()):
        if '.batch-quarantine' in candidate.parts:
            raise ValueError('quarantined batch receipts cannot be published or downloaded')
    return path
