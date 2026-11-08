#!/usr/bin/env python3
"""
Procedural 3D Tactical Quadcopter GLB Generator
Requirement 13 (Milestone 6) - DRONE_GCS

Generates a clean tactical quadcopter glTF 2.0 binary (.glb) model with:
- Central fuselage pod (dark titanium #152030)
- Avionics upper dome & GPS mast
- Directional forward nose chevron (#00D4FF cyan) pointing forward (-Z)
- 4 carbon fiber cantilever arms (X-frame layout)
- 4 motor bells and stator housings
- 2 forward spinning rotor disks (bright cyan #00D4FF)
- 2 rear spinning rotor disks (tactical gray #8090A0)
- 2 tubular landing skids with support struts
"""

import os
import sys
import argparse
import numpy as np
import trimesh


def create_cylinder_between(p1, p2, radius, sections=16, color=None):
    """Create a cylinder mesh spanning between two 3D points p1 and p2."""
    p1 = np.array(p1, dtype=float)
    p2 = np.array(p2, dtype=float)
    vec = p2 - p1
    length = np.linalg.norm(vec)
    if length < 1e-6:
        return trimesh.Trimesh()

    cyl = trimesh.creation.cylinder(radius=radius, height=length, sections=sections)
    # Default cylinder is along Z axis [-length/2, +length/2]
    # Align cylinder Z axis with vec
    direction = vec / length
    default_dir = np.array([0.0, 0.0, 1.0])

    if np.allclose(direction, default_dir):
        matrix = np.eye(4)
    elif np.allclose(direction, -default_dir):
        matrix = trimesh.transformations.rotation_matrix(np.pi, [1.0, 0.0, 0.0])
    else:
        rot_axis = np.cross(default_dir, direction)
        rot_axis = rot_axis / np.linalg.norm(rot_axis)
        rot_angle = np.arccos(np.clip(np.dot(default_dir, direction), -1.0, 1.0))
        matrix = trimesh.transformations.rotation_matrix(rot_angle, rot_axis)

    cyl.apply_transform(matrix)
    midpoint = (p1 + p2) / 2.0
    cyl.apply_translation(midpoint)

    if color is not None:
        cyl.visual.vertex_colors = np.tile(color, (len(cyl.vertices), 1))
    return cyl


def create_drone_model():
    """Build the tactical quadcopter multi-part mesh."""
    meshes = []

    # Color definitions (RGBA uint8)
    COLOR_TITANIUM   = [21, 32, 48, 255]     # Fuselage (#152030)
    COLOR_CARBON     = [26, 30, 36, 255]     # Carbon arms (#1A1E24)
    COLOR_MOTOR      = [43, 53, 69, 255]     # Motor housing (#2B3545)
    COLOR_CYAN_ROTOR = [0, 212, 255, 210]    # Front rotors (#00D4FF)
    COLOR_GRAY_ROTOR = [128, 144, 160, 210]  # Rear rotors (#8090A0)
    COLOR_CHEVRON    = [0, 212, 255, 255]    # Directional nose arrow
    COLOR_SKID       = [18, 22, 30, 255]     # Landing skids
    COLOR_DOME       = [37, 48, 64, 255]     # GPS dome

    # 1. Main Fuselage Body
    # In glTF 2.0: -Z is forward, +Y is up, +X is right
    fuse_box = trimesh.creation.box(extents=[0.14, 0.05, 0.32])
    fuse_box.apply_translation([0.0, 0.02, 0.0])
    fuse_box.visual.vertex_colors = np.tile(COLOR_TITANIUM, (len(fuse_box.vertices), 1))
    meshes.append(fuse_box)

    # Upper Fuselage Shell (aerodynamic top)
    fuse_top = trimesh.creation.box(extents=[0.10, 0.025, 0.22])
    fuse_top.apply_translation([0.0, 0.05, -0.01])
    fuse_top.visual.vertex_colors = np.tile(COLOR_TITANIUM, (len(fuse_top.vertices), 1))
    meshes.append(fuse_top)

    # GPS Dome Puck
    gps_dome = trimesh.creation.cylinder(radius=0.032, height=0.015, sections=20)
    # Default cylinder is along Z; rotate to Y axis
    gps_dome.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0]))
    gps_dome.apply_translation([0.0, 0.065, 0.02])
    gps_dome.visual.vertex_colors = np.tile(COLOR_DOME, (len(gps_dome.vertices), 1))
    meshes.append(gps_dome)

    # 2. Directional Nose Chevron (Arrow pointing towards -Z)
    chevron_pts = np.array([
        [0.0,    0.052, -0.19],   # Tip (forward)
        [-0.04,  0.052, -0.13],   # Left outer
        [-0.018, 0.052, -0.14],   # Left inner
        [0.018,  0.052, -0.14],   # Right inner
        [0.04,   0.052, -0.13],   # Right outer
    ])
    # Build a small prism for the chevron
    ch_top = chevron_pts + np.array([0.0, 0.008, 0.0])
    ch_bottom = chevron_pts.copy()
    ch_vertices = np.vstack([ch_bottom, ch_top])
    # Faces for chevron prism
    ch_faces = [
        # Top faces
        [5, 6, 7], [5, 7, 8], [5, 8, 9],
        # Bottom faces
        [0, 2, 1], [0, 3, 2], [0, 4, 3],
        # Sides
        [0, 1, 6], [0, 6, 5],
        [1, 2, 7], [1, 7, 6],
        [2, 3, 8], [2, 8, 7],
        [3, 4, 9], [3, 9, 8],
        [4, 0, 5], [4, 5, 9]
    ]
    chevron_mesh = trimesh.Trimesh(vertices=ch_vertices, faces=ch_faces)
    chevron_mesh.visual.vertex_colors = np.tile(COLOR_CHEVRON, (len(chevron_mesh.vertices), 1))
    meshes.append(chevron_mesh)

    # 3. Cantilever Arms (X-Frame)
    # Motor positions: wheelbase ~0.56m diagonal
    arm_x = 0.22
    arm_z = 0.22
    motor_y = 0.025

    motors = [
        {"name": "FL", "pos": [-arm_x, motor_y, -arm_z], "is_front": True},
        {"name": "FR", "pos": [ arm_x, motor_y, -arm_z], "is_front": True},
        {"name": "RL", "pos": [-arm_x, motor_y,  arm_z], "is_front": False},
        {"name": "RR", "pos": [ arm_x, motor_y,  arm_z], "is_front": False},
    ]

    for m in motors:
        # Arm cylinder from center to motor
        m_pos = m["pos"]
        start_pos = [m_pos[0] * 0.25, 0.015, m_pos[2] * 0.25]
        arm = create_cylinder_between(start_pos, m_pos, radius=0.012, sections=12, color=COLOR_CARBON)
        meshes.append(arm)

        # Motor Bell (Cylinder along Y)
        motor_bell = trimesh.creation.cylinder(radius=0.024, height=0.035, sections=16)
        motor_bell.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0]))
        motor_bell.apply_translation([m_pos[0], m_pos[1] + 0.015, m_pos[2]])
        motor_bell.visual.vertex_colors = np.tile(COLOR_MOTOR, (len(motor_bell.vertices), 1))
        meshes.append(motor_bell)

        # Motor Shaft / Cap
        cap = trimesh.creation.cylinder(radius=0.007, height=0.012, sections=12)
        cap.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0]))
        cap.apply_translation([m_pos[0], m_pos[1] + 0.035, m_pos[2]])
        cap.visual.vertex_colors = np.tile(COLOR_TITANIUM, (len(cap.vertices), 1))
        meshes.append(cap)

        # Rotor Disk (spinning propeller volume)
        rotor_color = COLOR_CYAN_ROTOR if m["is_front"] else COLOR_GRAY_ROTOR
        rotor_disk = trimesh.creation.cylinder(radius=0.13, height=0.006, sections=24)
        rotor_disk.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0]))
        rotor_disk.apply_translation([m_pos[0], m_pos[1] + 0.038, m_pos[2]])
        rotor_disk.visual.vertex_colors = np.tile(rotor_color, (len(rotor_disk.vertices), 1))
        meshes.append(rotor_disk)

        # Propeller Hub Blade cross
        blade1 = trimesh.creation.box(extents=[0.25, 0.004, 0.022])
        blade1.apply_translation([m_pos[0], m_pos[1] + 0.039, m_pos[2]])
        blade1.visual.vertex_colors = np.tile(rotor_color[:3] + [255], (len(blade1.vertices), 1))
        meshes.append(blade1)

    # 4. Landing Skids & Struts
    skid_x = 0.11
    skid_y = -0.075
    skid_radius = 0.007

    for sx in [-skid_x, skid_x]:
        # Horizontal skid bar
        bar = create_cylinder_between(
            [sx, skid_y, -0.19],
            [sx, skid_y,  0.19],
            radius=skid_radius, sections=12, color=COLOR_SKID
        )
        meshes.append(bar)

        # Front curved toe (kick-up)
        toe_f = create_cylinder_between(
            [sx, skid_y, -0.19],
            [sx, skid_y + 0.025, -0.23],
            radius=skid_radius, sections=10, color=COLOR_SKID
        )
        meshes.append(toe_f)

        # Rear curved heel
        heel_r = create_cylinder_between(
            [sx, skid_y,  0.19],
            [sx, skid_y + 0.020,  0.22],
            radius=skid_radius, sections=10, color=COLOR_SKID
        )
        meshes.append(heel_r)

        # Struts connecting to fuselage
        strut_f = create_cylinder_between(
            [sx * 0.75, 0.0, -0.09],
            [sx, skid_y, -0.09],
            radius=skid_radius, sections=10, color=COLOR_SKID
        )
        meshes.append(strut_f)

        strut_r = create_cylinder_between(
            [sx * 0.75, 0.0,  0.09],
            [sx, skid_y,  0.09],
            radius=skid_radius, sections=10, color=COLOR_SKID
        )
        meshes.append(strut_r)

    # Combine all sub-meshes into a single coherent scene/mesh
    combined = trimesh.util.concatenate(meshes)
    return combined


def main():
    parser = argparse.ArgumentParser(description="Generate 3D Tactical Drone GLB Model")
    parser.add_argument(
        "--output", "-o",
        default="map/models/drone.glb",
        help="Target output GLB path (default: map/models/drone.glb)"
    )
    args = parser.parse_args()

    out_path = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    print(f"Generating tactical quadcopter 3D model...")
    drone_mesh = create_drone_model()

    print(f"Drone mesh stats:")
    print(f"  Vertices: {len(drone_mesh.vertices)}")
    print(f"  Faces:    {len(drone_mesh.faces)}")
    print(f"  Bounds:   {drone_mesh.bounds.tolist()}")
    print(f"  Extents:  {drone_mesh.extents.tolist()}")

    scene = trimesh.Scene(geometry={"drone": drone_mesh})
    glb_data = trimesh.exchange.gltf.export_glb(scene)

    with open(out_path, "wb") as f:
        f.write(glb_data)

    print(f"Successfully generated GLB: {out_path} ({len(glb_data)} bytes)")


if __name__ == "__main__":
    main()
