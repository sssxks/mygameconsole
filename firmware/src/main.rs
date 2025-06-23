#![no_std]
#![no_main]

// Bring in a minimal panic handler so linking succeeds.
extern crate panic_halt;

use riscv_rt::entry;

mod hw;

use hw::{DISP_HEIGHT, DISP_WIDTH, Display, Keyboard};

/* ------------------------------------------------------------------------- */
/*                              2048 Game Code                               */
/* ------------------------------------------------------------------------- */

const GRID: usize = 4;
const TILE_SIZE: usize = 50; // pixel width/height of a tile (square)
const BOARD_LEFT: usize = (DISP_WIDTH - GRID * TILE_SIZE) / 2;
const BOARD_TOP: usize = (DISP_HEIGHT - GRID * TILE_SIZE) / 2;

#[derive(Copy, Clone)]
struct Game {
    grid: [[u8; GRID]; GRID], // 0 = empty, n => 2^n
    score: u32,
    rng: u32,
}

impl Game {
    const fn new() -> Self {
        Self {
            grid: [[0; GRID]; GRID],
            score: 0,
            rng: 1,
        }
    }

    #[inline(always)]
    fn next_rand(&mut self) -> u32 {
        // Very small `xorshift32` PRNG – fast & no_std friendly.
        let mut x = self.rng;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.rng = x;
        x
    }

    fn spawn_tile(&mut self) {
        // Collect empty tile positions.
        let mut empties = [0u8; GRID * GRID];
        let mut count = 0;
        for y in 0..GRID {
            for x in 0..GRID {
                if self.grid[y][x] == 0 {
                    empties[count] = (y * GRID + x) as u8;
                    count += 1;
                }
            }
        }
        if count == 0 {
            return;
        }
        let idx = (self.next_rand() % count as u32) as u8;
        let pos = empties[idx as usize] as usize;
        let y = pos / GRID;
        let x = pos % GRID;
        // 75% chance of a "2" (exp = 1), 25% chance of a "4" (exp = 2)
        self.grid[y][x] = if self.next_rand() & 3 == 0 { 2 } else { 1 };
    }

    fn reset(&mut self) {
        for y in 0..GRID {
            for x in 0..GRID {
                self.grid[y][x] = 0;
            }
        }
        self.score = 0;
        self.spawn_tile();
        self.spawn_tile();
    }

    // In-place slide/merge of a single 4-element line towards the start.
    fn slide_line(line: &mut [u8; GRID]) -> bool {
        let mut moved = false;
        // 1st pass – compact left.
        let mut target = 0;
        for i in 0..GRID {
            if line[i] != 0 {
                if i != target {
                    line[target] = line[i];
                    line[i] = 0;
                    moved = true;
                }
                target += 1;
            }
        }
        // 2nd pass – merge.
        for i in 0..GRID - 1 {
            if line[i] != 0 && line[i] == line[i + 1] {
                line[i] += 1; // increase exponent ⇒ value doubles
                line[i + 1] = 0;
                moved = true;
            }
        }
        // 3rd pass – compact again after merges.
        let mut target = 0;
        for i in 0..GRID {
            if line[i] != 0 {
                if i != target {
                    line[target] = line[i];
                    line[i] = 0;
                }
                target += 1;
            }
        }
        moved
    }

    fn make_move(&mut self, dir: Direction) -> bool {
        let mut moved = false;
        match dir {
            Direction::Left => {
                for y in 0..GRID {
                    moved |= Self::slide_line(&mut self.grid[y]);
                }
            }
            Direction::Right => {
                for y in 0..GRID {
                    let mut rev = self.grid[y];
                    rev.reverse();
                    let line_moved = Self::slide_line(&mut rev);
                    rev.reverse();
                    self.grid[y] = rev;
                    moved |= line_moved;
                }
            }
            Direction::Up => {
                for x in 0..GRID {
                    let mut col = [0u8; GRID];
                    for y in 0..GRID {
                        col[y] = self.grid[y][x];
                    }
                    let col_moved = Self::slide_line(&mut col);
                    for y in 0..GRID {
                        self.grid[y][x] = col[y];
                    }
                    moved |= col_moved;
                }
            }
            Direction::Down => {
                for x in 0..GRID {
                    let mut col = [0u8; GRID];
                    for y in 0..GRID {
                        col[y] = self.grid[GRID - 1 - y][x];
                    }
                    let col_moved = Self::slide_line(&mut col);
                    for y in 0..GRID {
                        self.grid[GRID - 1 - y][x] = col[y];
                    }
                    moved |= col_moved;
                }
            }
        }
        if moved {
            self.spawn_tile();
        }
        moved
    }

    /* ---------------------------- rendering helpers ---------------------------- */
    fn draw_rect(x0: usize, y0: usize, size: usize, color: u32) {
        for y in y0..(y0 + size) {
            for x in x0..(x0 + size) {
                Display::set_pixel(x, y, color);
            }
        }
    }

    fn color_for(exp: u8) -> u32 {
        match exp {
            0 => 0x111, // empty – dark grey
            1 => 0xEEE, // 2
            2 => 0xDD0, // 4
            3 => 0xFF8, // 8
            4 => 0xFB0, // 16
            5 => 0xF90, // 32
            6 => 0xF70, // 64
            7 => 0xF50, // 128
            8 => 0xF30, // 256+
            _ => 0xF00, // fallback – bright red
        }
    }

    fn render(&self) {
        // Clear the framebuffer.
        Display::fill(0x000);
        // Draw each tile.
        for y in 0..GRID {
            for x in 0..GRID {
                let exp = self.grid[y][x];
                let color = Self::color_for(exp);
                let px = BOARD_LEFT + x * TILE_SIZE;
                let py = BOARD_TOP + y * TILE_SIZE;
                Self::draw_rect(px, py, TILE_SIZE - 2, color);
            }
        }
    }
}

enum Direction {
    Up,
    Down,
    Left,
    Right,
}

/* ------------------------------------------------------------------------- */
/*                                   entry                                   */
/* ------------------------------------------------------------------------- */

#[entry]
fn main() -> ! {
    let mut keyboard = Keyboard::new();
    let mut game = Game::new();
    game.reset();
    game.render();

    loop {
        if keyboard.just_pressed('w') {
            if game.make_move(Direction::Up) {
                game.render();
            }
        }
        if keyboard.just_pressed('s') {
            if game.make_move(Direction::Down) {
                game.render();
            }
        }
        if keyboard.just_pressed('a') {
            if game.make_move(Direction::Left) {
                game.render();
            }
        }
        if keyboard.just_pressed('d') {
            if game.make_move(Direction::Right) {
                game.render();
            }
        }
        if keyboard.just_pressed('r') {
            game.reset();
            game.render();
        }
    }
}
