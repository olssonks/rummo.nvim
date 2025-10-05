import argparse
import importlib.util
import sys


def import_from_path(module_name, file_path):
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def make_arg_parser():
    parser = argparse.ArgumentParser(prog="rummo")

    parser.add_argument("user_notebook", help="Path to user notebook")
    parser.add_argument(
        "--no_matplotlib", help="Disable matplotlib", action="store_true"
    )
    return parser


def parse_args():
    parser = make_arg_parser()
    args = parser.parse_args()
    return args


# parser.add_argument("-i", "--ip", help="host IP address, default = 127.0.0.1", type=str)
#
# parser.add_argument(
#     "-p", "--port", help="host port, default=0 (picks random available port)", type=int
# )
