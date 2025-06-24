#!/usr/bin/env python3
# To run this script, you need to install the Pillow and NumPy libraries.
# You can install them by running this command in your terminal:
# pip install Pillow numpy

from PIL import Image
import numpy as np
import os
import argparse

def convert_image_to_coe(image_path, output_path, include_header=True, preview=False, preview_path=None):
    """
    Reads an image, converts its pixel data from RGB888 to RGB444 format,
    and writes the output to a Xilinx COE file. The pixel data is read
    in column-major order to match the original MATLAB script's behavior.

    Args:
        image_path (str): The path to the input image file (e.g., 'block2048.bmp').
        coe_path (str): The path for the output COE file (e.g., 'block2048.coe').
    """
    # --- 1. Load Image and Get Data ---
    # --- 1. 加载图像并获取数据 ---
    try:
        # Open the image file using Pillow
        # 这里是打开的bmp格式图片的名字
        img = Image.open(image_path)
    except FileNotFoundError:
        print(f"Error: The image file was not found at '{image_path}'")
        print("错误：找不到图像文件")
        return
    except Exception as e:
        print(f"An error occurred while opening the image: {e}")
        print(f"打开图像时发生错误: {e}")
        return

    # Convert image to RGB format if it's not already (e.g., if it's a palette image)
    # 如果图像不是RGB格式（例如，是带调色板的图像），则将其转换为RGB格式
    img = img.convert('RGB')

    # Get image dimensions. This avoids hardcoding sizes like 9384.
    # 获取图像尺寸。这避免了硬编码像 9384 这样的尺寸。
    width, height = img.size
    total_pixels = width * height
    print(f"Image dimensions: {width}x{height}, Total pixels: {total_pixels}")
    print(f"图像尺寸: {width}x{height}, 总像素数: {total_pixels}")

    # --- 2. Separate Channels and Flatten (Column-Major) ---
    # --- 2. 分离通道并按列优先展开 ---
    
    # Convert the Pillow image to a NumPy array. Shape is (height, width, 3)
    # 将Pillow图像转换为NumPy数组。形状为 (height, width, 3)
    img_array = np.array(img)

    # Separate the R, G, B channels
    # 分离通道
    r_channel = img_array[:, :, 0]
    g_channel = img_array[:, :, 1]
    b_channel = img_array[:, :, 2]

    # Flatten each channel's 2D matrix into a 1D vector.
    # The order 'F' specifies column-major flattening (like FORTRAN/MATLAB).
    # This is the Python equivalent of MATLAB's `reshape(channel', total_pixels, 1)`.
    # 降维2->1 (等同于 MATLAB 的 reshape(r',...))
    R_flat = r_channel.flatten(order='F')
    G_flat = g_channel.flatten(order='F')
    B_flat = b_channel.flatten(order='F')

    # --- 3. Convert from RGB888 to RGB444 ---
    # --- 3. 从 RGB888 转换为 RGB444 ---
    
    # This list will store the final 12-bit color values.
    # 此列表将存储最终的12位颜色值。
    rgb444_values = []
    
    # Iterate through each pixel's color data
    # 遍历每个像素的颜色数据
    for i in range(total_pixels):
        # rbg888->444
        # This is the Python equivalent of the MATLAB bitshift formula:
        # bitshift(bitshift(R(i),-4),8)+bitshift(bitshift(G(i),-4),4)+bitshift(B(i),-4),0)
        combined_value = ((R_flat[i] >> 4) << 8) | ((G_flat[i] >> 4) << 4) | (B_flat[i] >> 4)
        rgb444_values.append(combined_value)

    # --- 4. Optional preview of reduced colour depth ---
    if preview:
        preview_pixels = np.array(rgb444_values, dtype=np.uint16)
        # Extract 4-bit channels
        r4 = (preview_pixels >> 8) & 0xF
        g4 = (preview_pixels >> 4) & 0xF
        b4 = preview_pixels & 0xF
        # Expand to 8-bit by duplicating the nibble: rrrrrrrr = rrrrrrrr
        r8 = ((r4 << 4) | r4).astype(np.uint8)
        g8 = ((g4 << 4) | g4).astype(np.uint8)
        b8 = ((b4 << 4) | b4).astype(np.uint8)
        # Column-major to image matrix
        preview_arr = np.stack([r8, g8, b8], axis=1).reshape((height, width, 3), order='F')
        preview_img = Image.fromarray(preview_arr, mode='RGB')
        if preview_path is None:
            preview_path = os.path.splitext(output_path)[0] + '_preview.png'
        preview_img.save(preview_path)
        print(f"Preview image saved to '{preview_path}' (RGB444 → RGB888)")

    # --- 5. Write output file ---
    if not rgb444_values:
        print("Warning: No pixels were processed from the image.")
        print("警告：图像中没有可处理的像素。")
        return

    try:
        with open(output_path, 'w') as f:
            if include_header:
                # COE format
                f.write('MEMORY_INITIALIZATION_RADIX=16;\n')
                f.write('MEMORY_INITIALIZATION_VECTOR=\n')
                for i in range(len(rgb444_values) - 1):
                    f.write(f'{rgb444_values[i]:03x},\n')
                f.write(f'{rgb444_values[-1]:03x};\n')
            else:
                # Plain .hex format for Verilog $readmemh – one value per line
                for value in rgb444_values:
                    f.write(f'{value:03x}\n')
        print(f"Successfully created output file: '{output_path}'")
        print(f"成功创建输出文件: '{output_path}'")

    except IOError as e:
        print(f"An error occurred while writing to the file: {e}")
        print(f"写入文件时出错: {e}")


# Entry point
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert an image to Xilinx COE format or plain HEX for Verilog $readmemh.')
    parser.add_argument('input', help='Input image file')
    parser.add_argument('-o', '--output', help='Output file path. Default: same basename with .coe or .hex')
    parser.add_argument('--hex', action='store_true', help='Generate plain .hex file (no header/commas) suitable for $readmemh')
    parser.add_argument('--preview', action='store_true', help='Generate and save a preview PNG of the RGB444 image')
    parser.add_argument('--preview-path', help='Path to save the preview image (defaults to <output>_preview.png)')
    args = parser.parse_args()

    # Determine output filename
    if args.output:
        output_path = args.output
    else:
        base, _ = os.path.splitext(args.input)
        output_ext = '.hex' if args.hex else '.coe'
        output_path = base + output_ext

    # Create dummy image for quick testing when file does not exist
    if not os.path.exists(args.input):
        print(f"'{args.input}' not found. Creating a dummy image for demonstration.")
        dummy_img = Image.new('RGB', (96, 98), color='blue')
        dummy_img.save(args.input)
        print(f"Dummy image created: '{args.input}'")

    print('\nStarting conversion...')
    convert_image_to_coe(
        args.input,
        output_path,
        include_header=not args.hex,
        preview=args.preview,
        preview_path=args.preview_path
    )
