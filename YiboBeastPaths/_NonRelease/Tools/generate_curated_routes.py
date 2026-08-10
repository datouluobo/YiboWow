from __future__ import annotations

import math
import re
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.morphology import skeletonize


ROOT = Path(r"E:\Program\YiboBeastPaths")
CURATED_ROUTES_LUA = ROOT / "CuratedRoutes.lua"
ROUTE_OVERLAYS_LUA = ROOT / "RouteOverlays.lua"
ROUTE_TRANSFORMS_LUA = ROOT / "RouteTransforms.lua"
OVERLAYS_DIR = ROOT / "Assets" / "ExtractedRoutes" / "Overlays"

# Bombyx is intentionally authored as an ellipse on the world map, so we
# preserve that source shape instead of trying to skeletonize it into a line.
ELLIPSE_ROUTES = {
    66522: (192, 178, 404, 286),
}

# Some early routes were authored from ad-hoc reference images instead of the
# shipped 1.2 world-map overlays. Keep an explicit re-trace list so reruns can
# migrate those legacy exceptions back onto the overlay-aligned pipeline.
FORCE_RETRACE_ROUTES = {
    50812,
}


def parse_route_overlays() -> dict[int, dict[str, int | str]]:
    text = ROUTE_OVERLAYS_LUA.read_text(encoding="utf-8")
    overlays: dict[int, dict[str, int | str]] = {}
    for pet_id, slug, map_id in re.findall(
        r"\[(\d+)\] = \{\s+slug = \"([^\"]+)\",\s+mapID = (\d+),",
        text,
        re.S,
    ):
        overlays[int(pet_id)] = {"slug": slug, "mapID": int(map_id)}
    return overlays


def parse_route_transforms() -> dict[int, dict[str, float]]:
    text = ROUTE_TRANSFORMS_LUA.read_text(encoding="utf-8")
    transforms: dict[int, dict[str, float]] = {}
    for pet_id, offset_x, offset_y, scale, scale_x, scale_y in re.findall(
        r"\[(\d+)\] = \{ offsetX = ([^,]+), offsetY = ([^,]+), scale = ([^,]+), scaleX = ([^,]+), scaleY = ([^,]+),",
        text,
    ):
        transforms[int(pet_id)] = {
            "offsetX": float(offset_x),
            "offsetY": float(offset_y),
            "scale": float(scale),
            "scaleX": float(scale_x),
            "scaleY": float(scale_y),
        }
    return transforms


def extract_existing_route_blocks() -> dict[int, str]:
    text = CURATED_ROUTES_LUA.read_text(encoding="utf-8")
    lines = text.splitlines()
    blocks: dict[int, str] = {}
    index = 0

    while index < len(lines):
        match = re.match(r"\s*\[(\d+)\]\s*=\s*\{", lines[index])
        if not match:
            index += 1
            continue

        pet_id = int(match.group(1))
        start = index
        depth = 0
        while index < len(lines):
            depth += lines[index].count("{")
            depth -= lines[index].count("}")
            if depth == 0:
                block = "\n".join(lines[start : index + 1])
                blocks[pet_id] = block
                break
            index += 1
        index += 1

    return blocks


def get_neighbors(point: tuple[int, int], pixels: set[tuple[int, int]]) -> list[tuple[int, int]]:
    x, y = point
    neighbors: list[tuple[int, int]] = []
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            candidate = (x + dx, y + dy)
            if candidate in pixels:
                neighbors.append(candidate)
    return neighbors


def order_component_path(points: list[tuple[int, int]]) -> tuple[list[tuple[int, int]], bool]:
    pixels = set(points)
    degree = {point: len(get_neighbors(point, pixels)) for point in pixels}
    endpoints = [point for point, count in degree.items() if count <= 1]
    is_loop = len(endpoints) == 0
    start = min(endpoints or pixels, key=lambda point: (point[1], point[0]))
    ordered = [start]
    visited = {start}
    previous: tuple[int, int] | None = None
    current = start

    while True:
        candidates = [neighbor for neighbor in get_neighbors(current, pixels) if neighbor != previous]
        if not candidates:
            break

        next_point = None
        for candidate in sorted(candidates, key=lambda point: (point[1], point[0])):
            if candidate not in visited:
                next_point = candidate
                break

        if next_point is None:
            if is_loop:
                next_point = sorted(candidates, key=lambda point: (point[1], point[0]))[0]
            else:
                break

        if is_loop and next_point == start:
            ordered.append(next_point)
            break

        ordered.append(next_point)
        visited.add(next_point)
        previous, current = current, next_point

        if not is_loop and degree[current] <= 1:
            break
        if len(ordered) > len(points) + 2:
            break

    return ordered, is_loop


def rdp(points: list[tuple[float, float]], epsilon: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points

    (x1, y1), (x2, y2) = points[0], points[-1]
    dx = x2 - x1
    dy = y2 - y1
    denominator = math.hypot(dx, dy)
    max_distance = -1.0
    max_index = 0

    for index, (x, y) in enumerate(points[1:-1], start=1):
        if denominator == 0:
            distance = math.hypot(x - x1, y - y1)
        else:
            distance = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / denominator
        if distance > max_distance:
            max_distance = distance
            max_index = index

    if max_distance > epsilon:
        left = rdp(points[: max_index + 1], epsilon)
        right = rdp(points[max_index:], epsilon)
        return left[:-1] + right

    return [points[0], points[-1]]


def densify(points: list[tuple[float, float]], max_step: float = 14.0) -> list[tuple[float, float]]:
    dense = [points[0]]
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        distance = math.hypot(bx - ax, by - ay)
        steps = max(1, int(math.ceil(distance / max_step)))
        for step in range(1, steps + 1):
            t = step / steps
            dense.append((ax + (bx - ax) * t, ay + (by - ay) * t))
    return dense


def endpoint_distance(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def stitch_segments(
    segments: list[tuple[int, bool, list[tuple[float, float]]]],
    max_gap: float = 26.0,
) -> list[tuple[int, bool, list[tuple[float, float]]]]:
    stitched = list(segments)

    while True:
        best_pair = None
        best_gap = None

        for left_index in range(len(stitched)):
            left_weight, left_loop, left_points = stitched[left_index]
            if left_loop or len(left_points) < 2:
                continue

            for right_index in range(left_index + 1, len(stitched)):
                right_weight, right_loop, right_points = stitched[right_index]
                if right_loop or len(right_points) < 2:
                    continue

                candidates = [
                    ("tail-head", left_points[-1], right_points[0]),
                    ("tail-tail", left_points[-1], right_points[-1]),
                    ("head-head", left_points[0], right_points[0]),
                    ("head-tail", left_points[0], right_points[-1]),
                ]

                for mode, left_endpoint, right_endpoint in candidates:
                    gap = endpoint_distance(left_endpoint, right_endpoint)
                    if gap > max_gap:
                        continue
                    if best_gap is None or gap < best_gap:
                        best_gap = gap
                        best_pair = (left_index, right_index, mode)

        if best_pair is None:
            break

        left_index, right_index, mode = best_pair
        left_weight, _, left_points = stitched[left_index]
        right_weight, _, right_points = stitched[right_index]

        if mode == "tail-head":
            merged_points = left_points + right_points
        elif mode == "tail-tail":
            merged_points = left_points + list(reversed(right_points))
        elif mode == "head-head":
            merged_points = list(reversed(left_points)) + right_points
        else:
            merged_points = right_points + left_points

        deduped_points = [merged_points[0]]
        for point in merged_points[1:]:
            if endpoint_distance(point, deduped_points[-1]) >= 0.5:
                deduped_points.append(point)

        stitched[left_index] = (left_weight + right_weight, False, deduped_points)
        del stitched[right_index]

    return stitched


def invert_route_transform(
    normalized_x: float,
    normalized_y: float,
    transform: dict[str, float],
) -> tuple[float, float]:
    scale_x = transform["scale"] * transform["scaleX"]
    scale_y = transform["scale"] * transform["scaleY"]
    raw_x = 0.5 + ((normalized_x - 0.5 - transform["offsetX"]) / scale_x)
    raw_y = 0.5 + ((normalized_y - 0.5 - transform["offsetY"]) / scale_y)
    return raw_x, raw_y


def format_points(points: list[tuple[float, float]]) -> list[str]:
    lines: list[str] = []
    for index in range(0, len(points), 4):
        chunk = points[index : index + 4]
        rendered = ", ".join(f"{{ x = {x:.3f}, y = {y:.3f} }}" for x, y in chunk)
        lines.append(f"                    {rendered},")
    return lines


def average_route_color(image: np.ndarray, mask: np.ndarray) -> tuple[float, float, float, float]:
    rgb = image[:, :, :3][mask]
    if len(rgb) == 0:
        return 1.0, 1.0, 1.0, 1.0
    average = rgb.mean(axis=0) / 255.0
    return float(average[0]), float(average[1]), float(average[2]), 1.0


def generate_ellipse_segment(
    width: int,
    height: int,
    box: tuple[int, int, int, int],
    transform: dict[str, float],
) -> tuple[bool, list[tuple[float, float]]]:
    left, top, right, bottom = box
    center_x = (left + right) * 0.5
    center_y = (top + bottom) * 0.5
    radius_x = (right - left) * 0.5
    radius_y = (bottom - top) * 0.5
    points: list[tuple[float, float]] = []

    for index in range(25):
        angle = math.tau * index / 24.0
        pixel_x = center_x + math.cos(angle) * radius_x
        pixel_y = center_y + math.sin(angle) * radius_y
        normalized_x = pixel_x / (width - 1)
        normalized_y = pixel_y / (height - 1)
        points.append(invert_route_transform(normalized_x, normalized_y, transform))

    return True, points


def trace_overlay_segments(
    pet_id: int,
    slug: str,
    transform: dict[str, float],
) -> tuple[tuple[float, float, float, float], list[tuple[bool, list[tuple[float, float]]]]]:
    image = Image.open(OVERLAYS_DIR / f"{pet_id}_{slug}.tga").convert("RGBA")
    image_array = np.array(image)
    mask = image_array[:, :, 3] > 16
    color = average_route_color(image_array, mask)
    width, height = image.size

    if pet_id in ELLIPSE_ROUTES:
        return color, [generate_ellipse_segment(width, height, ELLIPSE_ROUTES[pet_id], transform)]

    skeleton = skeletonize(mask)
    neighbor_count = ndi.convolve(
        skeleton.astype(np.uint8),
        np.ones((3, 3), dtype=np.uint8),
        mode="constant",
        cval=0,
    ) - skeleton.astype(np.uint8)
    junction_pixels = skeleton & (neighbor_count >= 3)
    core_pixels = skeleton & (~junction_pixels)
    labels, component_count = ndi.label(core_pixels, structure=np.ones((3, 3), dtype=np.uint8))

    segments: list[tuple[int, bool, list[tuple[float, float]]]] = []

    for component_index in range(1, component_count + 1):
        component_points = [(int(x), int(y)) for y, x in np.argwhere(labels == component_index)]
        if len(component_points) < 20:
            continue

        ordered_points, is_loop = order_component_path(component_points)
        simplified_points = rdp(ordered_points, 1.8)
        simplified_points = densify(simplified_points, 14.0)
        if len(simplified_points) < 2:
            continue

        segments.append((len(component_points), is_loop, simplified_points))

    segments = stitch_segments(segments)
    transformed_segments: list[tuple[int, bool, list[tuple[float, float]]]] = []
    for weight, is_loop, pixel_points in segments:
        route_points: list[tuple[float, float]] = []
        for pixel_x, pixel_y in pixel_points:
            normalized_x = pixel_x / (width - 1)
            normalized_y = pixel_y / (height - 1)
            route_points.append(invert_route_transform(normalized_x, normalized_y, transform))
        transformed_segments.append((weight, is_loop, route_points))

    transformed_segments.sort(key=lambda item: item[0], reverse=True)
    return color, [(is_loop, points) for _, is_loop, points in transformed_segments]


def render_route_block(
    pet_id: int,
    map_id: int,
    color: tuple[float, float, float, float],
    slug: str,
    segments: list[tuple[bool, list[tuple[float, float]]]],
) -> str:
    lines = [
        f"    [{pet_id}] = {{",
        f"        mapID = {map_id},",
        f"        color = {{ {color[0]:.2f}, {color[1]:.2f}, {color[2]:.2f}, 1.00 }},",
        f"        source = \"Auto-traced from overlay {slug}\",",
        "        segments = {",
    ]

    for is_loop, points in segments:
        lines.append("            {")
        lines.append(f"                loop = {str(is_loop).lower()},")
        lines.append("                points = {")
        lines.extend(format_points(points))
        lines.append("                },")
        lines.append("            },")

    lines.append("        },")
    lines.append("    },")
    return "\n".join(lines)


def main() -> None:
    overlays = parse_route_overlays()
    transforms = parse_route_transforms()
    existing_blocks = extract_existing_route_blocks()

    rendered_blocks: dict[int, str] = dict(existing_blocks)

    for pet_id, overlay in overlays.items():
        if pet_id in rendered_blocks and pet_id not in FORCE_RETRACE_ROUTES:
            continue

        color, segments = trace_overlay_segments(
            pet_id,
            str(overlay["slug"]),
            transforms[pet_id],
        )
        rendered_blocks[pet_id] = render_route_block(
            pet_id,
            int(overlay["mapID"]),
            color,
            str(overlay["slug"]),
            segments,
        )
        print(
            f"generated route {pet_id} {overlay['slug']} with {len(segments)} segment(s)"
        )

    lines = [
        "local ns = select(2, ...)",
        "",
        "ns.curatedRoutes = {",
    ]

    for pet_id in sorted(rendered_blocks):
        lines.append(rendered_blocks[pet_id])

    lines.append("}")
    lines.append("")
    CURATED_ROUTES_LUA.write_text("\n".join(lines), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
