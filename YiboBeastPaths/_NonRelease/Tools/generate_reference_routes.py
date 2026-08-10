from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(r"E:\Program\YiboBeastPaths")
REFERENCE_ROUTES_LUA = ROOT / "ReferenceRoutes.lua"
CURATED_GENERATOR = ROOT / "_NonRelease" / "Tools" / "generate_curated_routes.py"


def load_curated_generator():
    spec = importlib.util.spec_from_file_location("generate_curated_routes", CURATED_GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load helper module: {CURATED_GENERATOR}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def render_reference_block(
    pet_id: int,
    map_id: int,
    color: tuple[float, float, float, float],
    slug: str,
    segments: list[tuple[bool, list[tuple[float, float]]]],
    display_segments: list[tuple[bool, list[tuple[float, float]]]],
    display_transform: dict[str, float],
    formatter,
) -> str:
    lines = [
        f"    [{pet_id}] = {{",
        f"        petID = {pet_id},",
        f"        mapID = {map_id},",
        f"        color = {{ {color[0]:.2f}, {color[1]:.2f}, {color[2]:.2f}, 1.00 }},",
        f"        source = \"Re-traced from legacy overlay {slug}\",",
        "        version = \"1.4.0-overlay-refresh\",",
        "        migratedFrom = \"Legacy overlay alignment refresh\",",
        (
            "        referenceDisplayTransform = "
            f"{{ offsetX = {display_transform['offsetX']:.4f}, offsetY = {display_transform['offsetY']:.4f}, "
            f"scaleX = {display_transform['scaleX']:.4f}, scaleY = {display_transform['scaleY']:.4f} }},"
        ),
        "        segments = {",
    ]

    for is_loop, points in segments:
        lines.append("            {")
        lines.append(f"                loop = {str(is_loop).lower()},")
        lines.append("                points = {")
        lines.extend(formatter(points))
        lines.append("                },")
        lines.append("            },")

    lines.append("        },")
    lines.append("    },")
    return "\n".join(lines)


def trace_overlay_display_segments(helper, pet_id: int, slug: str) -> list[tuple[bool, list[tuple[float, float]]]]:
    image = helper.Image.open(helper.OVERLAYS_DIR / f"{pet_id}_{slug}.tga").convert("RGBA")
    image_array = helper.np.array(image)
    mask = image_array[:, :, 3] > 16
    width, height = image.size

    if pet_id in helper.ELLIPSE_ROUTES:
        left, top, right, bottom = helper.ELLIPSE_ROUTES[pet_id]
        center_x = (left + right) * 0.5
        center_y = (top + bottom) * 0.5
        radius_x = (right - left) * 0.5
        radius_y = (bottom - top) * 0.5
        points: list[tuple[float, float]] = []
        for index in range(25):
            angle = helper.math.tau * index / 24.0
            pixel_x = center_x + helper.math.cos(angle) * radius_x
            pixel_y = center_y + helper.math.sin(angle) * radius_y
            points.append((pixel_x / (width - 1), pixel_y / (height - 1)))
        return [(True, points)]

    skeleton = helper.skeletonize(mask)
    neighbor_count = helper.ndi.convolve(
        skeleton.astype(helper.np.uint8),
        helper.np.ones((3, 3), dtype=helper.np.uint8),
        mode="constant",
        cval=0,
    ) - skeleton.astype(helper.np.uint8)
    junction_pixels = skeleton & (neighbor_count >= 3)
    core_pixels = skeleton & (~junction_pixels)
    labels, component_count = helper.ndi.label(core_pixels, structure=helper.np.ones((3, 3), dtype=helper.np.uint8))

    segments: list[tuple[int, bool, list[tuple[float, float]]]] = []
    for component_index in range(1, component_count + 1):
        component_points = [(int(x), int(y)) for y, x in helper.np.argwhere(labels == component_index)]
        if len(component_points) < 20:
            continue

        ordered_points, is_loop = helper.order_component_path(component_points)
        simplified_points = helper.rdp(ordered_points, 1.8)
        simplified_points = helper.densify(simplified_points, 14.0)
        if len(simplified_points) < 2:
            continue

        segments.append((len(component_points), is_loop, simplified_points))

    segments = helper.stitch_segments(segments)
    segments.sort(key=lambda item: item[0], reverse=True)
    return [
        (
            is_loop,
            [
                (pixel_x / (width - 1), pixel_y / (height - 1))
                for pixel_x, pixel_y in points
            ],
        )
        for _, is_loop, points in segments
    ]


def collect_points(segments: list[tuple[bool, list[tuple[float, float]]]]) -> list[tuple[float, float]]:
    collected: list[tuple[float, float]] = []
    for _, points in segments:
        collected.extend(points)
    return collected


def compute_bounds(points: list[tuple[float, float]]) -> dict[str, float]:
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return {
        "minX": min(xs),
        "maxX": max(xs),
        "minY": min(ys),
        "maxY": max(ys),
    }


def transform_route_points(
    segments: list[tuple[bool, list[tuple[float, float]]]],
    transform: dict[str, float],
) -> list[tuple[bool, list[tuple[float, float]]]]:
    transformed: list[tuple[bool, list[tuple[float, float]]]] = []
    for is_loop, points in segments:
        mapped_points = []
        for x, y in points:
            mapped_x = 0.5 + transform["offsetX"] + ((x - 0.5) * transform["scale"] * transform["scaleX"])
            mapped_y = 0.5 + transform["offsetY"] + ((y - 0.5) * transform["scale"] * transform["scaleY"])
            mapped_points.append((mapped_x, mapped_y))
        transformed.append((is_loop, mapped_points))
    return transformed


def compute_display_transform(
    route_segments: list[tuple[bool, list[tuple[float, float]]]],
    overlay_segments: list[tuple[bool, list[tuple[float, float]]]],
    route_transform: dict[str, float],
) -> dict[str, float]:
    route_map_segments = transform_route_points(route_segments, route_transform)
    route_points = collect_points(route_map_segments)
    overlay_points = collect_points(overlay_segments)

    route_bounds = compute_bounds(route_points)
    overlay_bounds = compute_bounds(overlay_points)

    route_width = max(0.0001, route_bounds["maxX"] - route_bounds["minX"])
    route_height = max(0.0001, route_bounds["maxY"] - route_bounds["minY"])
    overlay_width = max(0.0001, overlay_bounds["maxX"] - overlay_bounds["minX"])
    overlay_height = max(0.0001, overlay_bounds["maxY"] - overlay_bounds["minY"])

    scale_x = overlay_width / route_width
    scale_y = overlay_height / route_height

    route_center_x = (route_bounds["minX"] + route_bounds["maxX"]) * 0.5
    route_center_y = (route_bounds["minY"] + route_bounds["maxY"]) * 0.5
    overlay_center_x = (overlay_bounds["minX"] + overlay_bounds["maxX"]) * 0.5
    overlay_center_y = (overlay_bounds["minY"] + overlay_bounds["maxY"]) * 0.5

    offset_x = overlay_center_x - route_center_x
    offset_y = overlay_center_y - route_center_y

    return {
        "offsetX": offset_x,
        "offsetY": offset_y,
        "scaleX": scale_x,
        "scaleY": scale_y,
    }


def main() -> None:
    helper = load_curated_generator()
    overlays = helper.parse_route_overlays()
    transforms = helper.parse_route_transforms()

    rendered_blocks: dict[int, str] = {}
    for pet_id, overlay in overlays.items():
        color, segments = helper.trace_overlay_segments(
            pet_id,
            str(overlay["slug"]),
            transforms[pet_id],
        )
        display_segments = trace_overlay_display_segments(helper, pet_id, str(overlay["slug"]))
        display_transform = compute_display_transform(segments, display_segments, transforms[pet_id])
        rendered_blocks[pet_id] = render_reference_block(
            pet_id,
            int(overlay["mapID"]),
            color,
            str(overlay["slug"]),
            segments,
            display_segments,
            display_transform,
            helper.format_points,
        )
        print(f"generated reference route {pet_id} {overlay['slug']} with {len(segments)} segment(s)")

    lines = [
        "local ns = select(2, ...)",
        "",
        "ns.referenceRoutes = {",
    ]

    for pet_id in sorted(rendered_blocks):
        lines.append(rendered_blocks[pet_id])

    lines.append("}")
    lines.append("")
    REFERENCE_ROUTES_LUA.write_text("\n".join(lines), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
