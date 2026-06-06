#!/usr/bin/env python3

# Yeah this is going in the assets shut up

# Do I look like I know what a shellscript is?
# I just want a spritesheet of a god dang emote

from math import floor
import os
import re
import subprocess
from subprocess import run
import sys


RE_GEOMETRY = re.compile(rb"\d+x\d+")

def get_ideal_tile_geometry(frame_count: int) -> str:
	if frame_count <= 32:
		return f"{frame_count}x1"
	full_rows, last_row = divmod(frame_count, 32)
	if last_row == 0:
		return "32x{full_rows}"
	total_rows = full_rows + 1
	free_spaces = 32 - last_row
	return f"{32 - floor(free_spaces / total_rows)}x{total_rows}"


def _failed(cp: subprocess.CompletedProcess) -> bool:
	return cp.returncode != 0

def main(filename: str) -> int:
	head, tail = os.path.splitext(filename)
	tmp_filename = head + "_tmp" + tail
	spritesheet_filename = head + ".png"

	if _failed(p := run(["convert", "-layers", "Coalesce", filename, tmp_filename])):
		return 1

	if _failed(p := run(["identify", tmp_filename], capture_output=True)):
		print(p.stderr)
		return 1

	frame_count = p.stdout.count(b'\n')
	# geometry = RE_GEOMETRY.search(p.stdout)[0].decode("utf-8")
	geometry = "28x28"

	if _failed(
		p := run([
			"montage", tmp_filename, "-tile", get_ideal_tile_geometry(frame_count),
			"-geometry", geometry, "-alpha", "On", "-background", "rgba(0, 0, 0, 0.0)",
			"-quality", "100", spritesheet_filename,
		])
	):
		return 1

	run(["rm", tmp_filename])

	return 0


if __name__ == "__main__":
	image_name = sys.argv[1]
	sys.exit(main(image_name))
