import json
from copy import deepcopy
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Tuple, Union

import marimo as mo
from marimo._ast.app import App as MarimoApp
from marimo._ast.cell import Cell

CELL_JSON_PREFIX = "rummo_"


@dataclass
class rummoCell:
    short_id: str = ""
    name: str = ""
    stale: bool = False
    output: list[str] = field(default_factory=list)
    output_line_count = 0
    img_files: list[str] = field(default_factory=list)
    cell_type = ""  # like code, markdown, and any others
    cell_id: str = ""
    cell_index = 0


def check_rummo_dir(user_app: MarimoApp):
    rummo_dir = Path(user_app._filename).parent / "__marimo__" / "__rummo__"
    if not rummo_dir.exists():
        rummo_dir.mkdir(parents=True, exist_ok=True)
    return rummo_dir


def check_rummo_file(user_app: MarimoApp):
    rummo_dir = check_rummo_dir(user_app)
    rummo_file = rummo_dir / f"{Path(user_app._filename).stem}.json"
    if not rummo_file.exists():
        rummo_file.touch()
    return rummo_file


def short_cell_id(full_cell_id: str) -> str:
    """Extract unique string from a `marimo` `cell_id` string.

    The last 4 characters of a marimo cell ID is unique to the cell. The other
    characters are a common prefix for the app instance.

    Args:
        full_cell_id: ID to shorten

    Returns:
        Last four characters of the full cell ID. These are the UUID that are unique
        to the cell.

    """
    return full_cell_id[-4:]


def update_rummoCell(
    rummo_cell: Union[rummoCell, None], cell: Union[Cell, None]
) -> Union[rummoCell, None]:
    """Updates a `rummoCell` based on the provided `marimo.Cell`.

    If no `rummoCell` is given, a new `rummoCell` is created and updated.

    Args:
        cell: `marimo.Cell` used to create `rummo_Cell`

    Returns:
        `rummo_Cell`
    """
    if not cell:
        return None
    if not rummo_cell:
        rummo_cell = rummoCell()
    rummo_cell.short_id = short_cell_id(cell._cell.cell_id)
    rummo_cell.cell_id = cell._cell.cell_id
    rummo_cell.name = cell.name
    rummo_cell.stale = cell._cell.stale
    rummo_cell.output_line_count, rummo_cell.output = process_output(
        cell._cell._output.output
    )
    rummo_cell.cell_index = getattr(rummo_cell, "rummo_cell_index", 0)
    return rummo_cell


def init_rummoCell_holder(user_app: MarimoApp) -> Dict[str, rummoCell]:
    """Dict of `rummo_Cell`s indexed by their `name`, i.e. the name of the cell function in the notebook.

    Args:
        user_app: [TODO:description]

    Returns:
        [TODO:return]
    """
    cell_holder = refresh_holder({}, user_app)
    return cell_holder


def write_rummo_file(rummoCell_holder: Dict[str, rummoCell], user_app: MarimoApp):
    rummo_file = check_rummo_file(user_app)
    cell_indices = {
        cell.cell_index: cell_name for cell_name, cell in rummoCell_holder.items()
    }
    # cell_names = list(rummoCell_holder.keys())
    # cell_names.sort()
    cells_as_dicts = {
        cell_name: rummoCell_holder[cell_name].__dict__
        for _, cell_name in sorted(cell_indices.items())
    }
    with open(rummo_file, "w") as f:
        json.dump(cells_as_dicts, f, indent=2)
    return rummoCell_holder


def refresh_holder(
    rummoCell_holder: Dict[str, rummoCell], user_app: MarimoApp
) -> Dict[str, rummoCell]:
    marimo_cell_dict = {
        cell_id: cell_data.cell
        for cell_id, cell_data in user_app._cell_manager._cell_data.items()
    }
    for c_idx, _cell in enumerate(marimo_cell_dict.values()):
        setattr(_cell, "rummo_cell_index", c_idx)
    rummo_cell_names = {_c.cell_id: _n for _n, _c in rummoCell_holder.items()}

    to_update = set(marimo_cell_dict.keys()).intersection(set(rummo_cell_names.keys()))
    to_make = set(marimo_cell_dict.keys()).difference(set(rummo_cell_names.keys()))
    to_delete = set(rummo_cell_names.keys()).difference(set(marimo_cell_dict.keys()))

    for c_id in to_update:
        update_rummoCell(
            rummoCell_holder[rummo_cell_names[c_id]], marimo_cell_dict[c_id]
        )
    for c_id in to_make:
        rummoCell_holder.update(
            {
                marimo_cell_dict[c_id].name: update_rummoCell(
                    None, marimo_cell_dict[c_id].cell
                )
            }
        )
    for c_id in to_delete:
        rummoCell_holder.pop(rummo_cell_names[c_id])

    return rummoCell_holder


def process_output(cell_output: str) -> Tuple[int, List[str]]:
    """Splits lines of raw output text.

    May need some extra handling in the case the raw text has newlines that we want
    to preserve, `\\n` to `\\\\n`. This case is probably rare, or never happens.

    Args:
        cell_output: String of cell output.

    Returns:
        Tuple with the number of lines and the list of split lines.
    """
    line_count = 0
    line_list = []
    if cell_output:
        line_list = cell_output.splitlines()
        line_count = len(line_list)
    return (line_count, line_list)


def rummo_run(rummo_Cell_holder: Dict[str, rummoCell], user_app: MarimoApp):
    """
    Do the Following:
        - run cell
        - collect output
        - update cell handler
        - update file

    For non-automatic execution, maybe some logic based on stale state
    """
    with mo.capture_stdout() as output_buffer, mo.capture_stderr() as error_buffer:
        try:
            for cell_id, cell_data in user_app._cell_manager._cell_data.items():
                _out, defs = cell_data.cell.run()
                output = output_buffer.getvalue()
                cell_data.cell._cell.set_output(output)
                output_buffer.seek(0)
                output_buffer.truncate(0)
        except:
            err = error_buffer.getvalue()
            cell_data.cell._cell.set_output(err)
            error_buffer.seek(0)
            error_buffer.truncate(0)
    refresh_holder(rummo_Cell_holder, user_app)
    write_rummo_file(rummo_Cell_holder, user_app)
    return
