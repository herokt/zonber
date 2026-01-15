import 'dart:math';

class MazeGenerator {
  final int rows;
  final int cols;
  final int? seed;
  late final Random _rng;

  MazeGenerator(this.rows, this.cols, {this.seed}) {
    _rng = seed != null ? Random(seed) : Random();
  }

  /// Generates a maze using Recursive Backtracker.
  /// Returns a list of simple wall definitions.
  /// Each wall is defined as [x, y, isHorizontal].
  /// Coordinates are in grid units (col, row).
  List<List<dynamic>> generate() {
    // 1. Initialize grid (Visited flags)
    // We don't implicitly store walls; we assume walls everywhere and carve paths (remove walls).
    // Or simpler: We generate walls.
    // Recursive Backtracker carves PATHS.
    // So distinct Sets approach? Or Stack?
    // Let's use Stack.

    // Grid of cells. Each cell has [top, right, bottom, left] walls.
    // Initially ALL walls exist.
    // Note: cell[0][0].right is same as cell[1][0].left.
    // Easier to store:
    // verticalWalls[cols+1][rows] (vertical lines)
    // horizontalWalls[cols][rows+1] (horizontal lines)

    // Actually, simpler for output:
    // Store walls as boolean 2D arrays?
    // Let's use 2D array of "Cells" with visited flag.

    List<List<bool>> visited = List.generate(
      cols,
      (_) => List.filled(rows, false),
    );

    // Store where we have CARVED a path (removed a wall).
    // Start with all walls = true.
    List<List<bool>> verticalWalls = List.generate(
      cols + 1,
      (_) => List.filled(rows, true),
    );
    List<List<bool>> horizontalWalls = List.generate(
      cols,
      (_) => List.filled(rows + 1, true),
    );

    // Stack for backtracking [col, row]
    List<List<int>> stack = [];

    // Start at random cell
    int startCol = _rng.nextInt(cols);
    int startRow = _rng.nextInt(rows);

    // Mark start as visited
    visited[startCol][startRow] = true;
    stack.add([startCol, startRow]);

    while (stack.isNotEmpty) {
      List<int> current = stack.last; // Peek
      int cx = current[0];
      int cy = current[1];

      // Find unvisited neighbors
      List<List<int>> neighbors = [];

      // Up
      if (cy > 0 && !visited[cx][cy - 1])
        neighbors.add([cx, cy - 1, 0]); // 0=Up
      // Right
      if (cx < cols - 1 && !visited[cx + 1][cy])
        neighbors.add([cx + 1, cy, 1]); // 1=Right
      // Down
      if (cy < rows - 1 && !visited[cx][cy + 1])
        neighbors.add([cx, cy + 1, 2]); // 2=Down
      // Left
      if (cx > 0 && !visited[cx - 1][cy])
        neighbors.add([cx - 1, cy, 3]); // 3=Left

      if (neighbors.isNotEmpty) {
        // Choose random neighbor
        List<int> next = neighbors[_rng.nextInt(neighbors.length)];
        int nx = next[0];
        int ny = next[1];
        int dir = next[2];

        // Remove wall
        if (dir == 0) {
          // Up
          horizontalWalls[cx][cy] = false; // Wall above current (at y)
        } else if (dir == 1) {
          // Right
          verticalWalls[cx + 1][cy] = false; // Wall right of current
        } else if (dir == 2) {
          // Down
          horizontalWalls[cx][cy + 1] = false; // Wall below current (at y+1)
        } else if (dir == 3) {
          // Left
          verticalWalls[cx][cy] = false; // Wall left of current
        }

        // Mark visited
        visited[nx][ny] = true;
        stack.add([nx, ny]);
      } else {
        // Backtrack
        stack.removeLast();
      }
    }

    // Convert walls to list of simple instructions
    List<List<dynamic>> walls = [];

    // Skip borders if desired, or keep them.
    // Game likely has its own borders? ZonberGame.mapWidth limit.
    // Let's keep borders in valid wall list, but maybe we want entrances?
    // No, standard Zonber map is closed arena usually.

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r <= rows; r++) {
        if (horizontalWalls[c][r]) {
          walls.add([c, r, true]); // Horizontal at col c, row r
        }
      }
    }
    for (int c = 0; c <= cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (verticalWalls[c][r]) {
          walls.add([c, r, false]); // Vertical at col c, row r
        }
      }
    }

    return walls;
  }
}
