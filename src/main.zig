const std = @import("std");

const rl = @cImport(@cInclude("raylib.h"));

// helper: int to string
fn itoa(i: i32) [*c]const u8 {
    const buf = str_buf[0 .. str_buf.len - 1];
    const slice = std.fmt.bufPrint(buf, "{}", .{i}) catch {
        return "error";
    };

    str_buf[slice.len] = 0;
    return @ptrCast(slice);
}

const window_width = 800;
const window_height = 600;

const GameState = enum { start, playing, paused, win };

const Player = struct {
    rect: rl.Rectangle,
    score: i32,

    const height = 60;
    const width = 15;
    const speed = 300;

    fn update(self: *Player, move: f32) void {
        const y = self.rect.y + move;
        if (y < 0 or y + self.rect.height > window_height) {
            return;
        }

        self.rect.y = y;
    }

    fn reset(self: *Player, x: f32) void {
        self.rect = .{ .x = x, .y = window_height / 2 - Player.height / 2, .width = width, .height = height };
        self.score = 0;
    }
};

const Ball = struct {
    rect: rl.Rectangle,
    velocity: rl.Vector2,

    const speed = 500;
    const size = 20;

    fn reset(self: *Ball) void {
        const random_y = @as(f32, @floatFromInt(rl.GetRandomValue(-100, 100)));
        self.rect = .{
            .x = window_width / 2 - Ball.size / 2,
            .y = window_height / 2 - Ball.size / 2,
            .width = Ball.size,
            .height = Ball.size,
        };
        self.velocity = rl.Vector2{
            .x = if (rl.GetRandomValue(0, 1) == 0) -Ball.speed else Ball.speed,
            .y = random_y,
        };
    }
};

var game_state: GameState = .start;
var ball: Ball = undefined;
var player_1: Player = undefined;
var player_2: Player = undefined;

var str_buf: [10]u8 = undefined; // itoa() will use this

pub fn main() !void {
    rl.InitWindow(window_width, window_height, "Pong!");
    rl.SetTargetFPS(60);

    reset_game();

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_ESCAPE)) {
            break;
        } else if (rl.IsKeyPressed(rl.KEY_P)) {
            if (game_state == .playing) game_state = .paused else if (game_state == .paused) game_state = .playing;
        } else if (rl.IsKeyPressed(rl.KEY_ENTER) and (game_state == .win or game_state == .start)) {
            reset_game();
            game_state = .playing;
        }

        switch (game_state) {
            .start => draw_start(),
            .playing => {
                update_game();
                draw_game();
            },
            .paused => draw_pause(),
            .win => draw_winner(),
        }
    }

    rl.CloseWindow();
}

fn reset_game() void {
    ball.reset();
    player_1.reset(10);
    player_2.reset(window_width - 20);
}

fn update_game() void {
    const frame_time = rl.GetFrameTime();

    // controls for player 1
    if (rl.IsKeyDown(rl.KEY_W)) {
        player_1.update(-Player.speed * frame_time);
    }
    if (rl.IsKeyDown(rl.KEY_S)) {
        player_1.update(Player.speed * frame_time);
    }

    // controls for player 2
    if (rl.IsKeyDown(rl.KEY_UP)) {
        player_2.update(-Player.speed * frame_time);
    }
    if (rl.IsKeyDown(rl.KEY_DOWN)) {
        player_2.update(Player.speed * frame_time);
    }

    // move ball
    ball.rect.x += ball.velocity.x * frame_time;
    ball.rect.y += ball.velocity.y * frame_time;

    // collisions (wall)
    if (ball.rect.y <= 0 or ball.rect.y + ball.rect.height >= window_height) {
        ball.velocity.y = -ball.velocity.y;
    }

    // collisions (paddles)
    if (rl.CheckCollisionRecs(ball.rect, player_1.rect)) {
        ball.velocity.x = -ball.velocity.x;
    }
    if (rl.CheckCollisionRecs(ball.rect, player_2.rect)) {
        ball.velocity.x = -ball.velocity.x;
    }

    // scoring situation
    if (ball.rect.x <= 0) {
        player_2.score += 1;
        ball.reset();
    } else if (ball.rect.x + ball.rect.width >= window_width) {
        player_1.score += 1;
        ball.reset();
    }

    // check winning
    if (player_1.score == 10 or player_2.score == 10)
        game_state = .win;
}

fn draw_start() void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);
    defer rl.EndDrawing();

    const title = "PONG!!";
    const fonst_size = 50;

    rl.DrawText(title, @divTrunc(window_width, 2) - @divTrunc(rl.MeasureText(title, fonst_size), 2), window_height / 2 - 50, fonst_size, rl.YELLOW);
}

fn draw_game() void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);
    defer rl.EndDrawing();

    rl.DrawRectangleRec(player_1.rect, rl.WHITE);
    rl.DrawRectangleRec(player_2.rect, rl.WHITE);
    rl.DrawRectangleRec(ball.rect, rl.WHITE);

    rl.DrawText(itoa(player_1.score), 30, 30, 20, rl.GREEN);
    rl.DrawText(itoa(player_2.score), window_width - 30 - rl.MeasureText(itoa(player_2.score), 20), 30, 20, rl.GREEN);
}

fn draw_pause() void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);
    defer rl.EndDrawing();

    const pause_text = "Paused";
    const font_size = 40;

    rl.DrawText(pause_text, @divTrunc(window_width, 2) - @divTrunc(rl.MeasureText(pause_text, font_size), 2), window_height / 2 - 50, font_size, rl.YELLOW);
}

fn draw_winner() void {
    rl.BeginDrawing();
    rl.ClearBackground(rl.BLACK);
    defer rl.EndDrawing();

    const winner_text = if (player_1.score > player_2.score) "Player 1 Wins!" else "Player 2 Wins!";
    const font_size = 40;

    rl.DrawText(winner_text, @divTrunc(window_width, 2) - @divTrunc(rl.MeasureText(winner_text, font_size), 2), window_height / 2 - 50, font_size, rl.YELLOW);
}
