from pathlib import Path

import marimo as mo
import matplotlib.pyplot as plt
from marimo._ast.app import App
from marimo._output.mpl import (
    CellChannel,
    CellOp,
    KnownMimeType,
    Optional,
    _internal_show,
)
from matplotlib._pylab_helpers import Gcf
from matplotlib.backend_bases import (
    FigureCanvasBase,
    FigureManagerBase,
)
from matplotlib.backends.backend_agg import FigureCanvasAgg

from .core import check_rummo_dir, short_cell_id

user_app = App()

FORMAT = "png"


class FigureManagerRummo(FigureManagerBase):
    def __init__(self, canvas, num):
        global user_app
        self.user_app = user_app
        super().__init__(canvas, num)
        return

    def show(self):
        _internal_show_rummo(self.canvas, self.user_app)
        return


class FigureCanvasRummo(FigureCanvasAgg):
    manager_class = FigureManagerRummo


def close_figures() -> None:
    if Gcf.get_all_fig_managers():
        plt.close("all")


def _internal_show_rummo(canvas: FigureCanvasBase, user_app: App) -> None:
    rummo_dir = check_rummo_dir(user_app)
    user_nb_name = Path(user_app._filename).stem

    cell_id = mo._runtime.app_meta.get_context().cell_id
    # cell = user_app._cell_manager._cell_data[cell_id]
    filenames = []
    for num, figmanager in enumerate(Gcf.get_all_fig_managers()):
        fname = (
            rummo_dir
            / f"{user_nb_name}_{short_cell_id(cell_id)}_fig-{num + 1}.{FORMAT}"
        )
        figmanager.canvas.figure.savefig(fname)
        filenames.append(fname)

    mimetype: KnownMimeType = "text/plain"
    CellOp.broadcast_output(
        channel=CellChannel.OUTPUT,
        mimetype=mimetype,
        data=",".join(filenames),
        cell_id=cell_id,
        status=None,
    )
    _internal_show(canvas)
    return


def show(*, block: Optional[bool] = None) -> None:
    global user_app
    del block
    for manager in Gcf.get_all_fig_managers():
        _internal_show_rummo(manager.canvas, user_app)


def _broadcast_fig_files():
    return


FigureManager = FigureManagerRummo
FigureCanvas = FigureCanvasRummo
