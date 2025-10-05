# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "fastapi==0.115.12",
#     "marimo",
#     "mohtml==0.1.10",
#     "requests==2.32.3",
#     "uvicorn==0.34.3",
# ]
# ///
# adapted from marimo-team github example: marimo-team/youtube-material/examples/serv.py

import marimo

__generated_with = "0.16.1"
app = marimo.App(width="columns")

with app.setup:
    # Initialization code that runs before all other cells
    import sys
    import marimo as mo

    import rummo

    #args = rummo.parse_args()

    args = {'user_notebook': './user_notebook.py', "no_matplotlib":False}

    user_notebook = rummo.import_from_path("user_notebook", args['user_notebook'])

    user_app = user_notebook.app
    #from user_notebook import app as user_app

    if args['no_matplotlib']:

        import rummo.mpl_backend

        module = sys.modules["rummo.mpl_backend"]
        setattr(module, "user_app", user_app)

        import matplotlib

        matplotlib.use("module://rummo.mpl_backend")

        import matplotlib.pyplot as plt


@app.cell
def _():
    user_app._cell_manager._cell_data
    return


@app.cell
def _():
    cell_holder = rummo.core.init_rummoCell_holder(user_app)
    return (cell_holder,)


@app.cell
def _(cell_holder):
    #breakpoint()
    rummo.core.rummo_run(cell_holder, user_app)
    return


@app.cell
def _(cell_holder):
    cell_holder
    return


@app.cell
def _():
    output, defs = list(user_app._cell_manager.cells())[1].run()
    return


@app.cell
def _():
    return


if __name__ == "__main__":
    app.run()
