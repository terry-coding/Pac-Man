import SwiftUI

// 遊戲狀態枚舉
enum GameState {
    case playing, paused, gameOver, victory
}

// 方向枚舉
enum Direction {
    case up, down, left, right, none
}

// 格子類型
enum CellType {
    case empty, wall, dot, powerDot
}

// 遊戲紀錄結構
struct GameRecord: Identifiable, Codable {
    var id: UUID
    let score: Int
    let timeSpent: Double
    let date: Date
    
    init(score: Int, timeSpent: Double, date: Date) {
        self.id = UUID()
        self.score = score
        self.timeSpent = timeSpent
        self.date = date
    }
}

struct Ghost: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var direction: Direction = .right
}

struct PacmanShape: Shape {
    let direction: Direction
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // 根據方向旋轉
        let rotation: Double
        switch direction {
        case .right: rotation = 0
        case .down: rotation = 90
        case .left: rotation = 180
        case .up: rotation = 270
        case .none: rotation = 0
        }
        
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: .degrees(rotation + 45),
                   endAngle: .degrees(rotation + 315),
                   clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

struct ContentView: View {
    // 遊戲狀態
    @State private var gameState: GameState = .playing
    @State private var pacmanPosition = CGPoint(x: 20, y: 20)
    @State private var currentDirection: Direction = .none
    @State private var score = 0
    @State private var dots: [CGPoint] = []
    @State private var ghosts: [Ghost] = []
    @State private var walls: [CGPoint] = []
    @State private var timeRemaining: Double = 180 // 3分鐘
    @State private var gameStartTime: Date?
    @State private var gameRecords: [GameRecord] = []
    @State private var showingLeaderboard = false
    
    // 計時器
    @State private var pacmanTimer: Timer?
    @State private var ghostTimer: Timer?
    @State private var gameTimer: Timer?
    
    // 遊戲常數
    let gridSize = 15
    let cellSize: CGFloat = UIScreen.main.bounds.width / CGFloat(15) // 根據螢幕寬度計算格子大小
    let scaleFactor: CGFloat = 0.9 // 遊戲物件縮放因子
    let buttonSize: CGFloat = UIScreen.main.bounds.width / 5 // 按鈕大小根據螢幕寬度調整
    let pacmanSpeed: Double = 0.25
    let ghostSpeed: Double = 0.9
    
    @State private var pressedButton: Direction? = nil // 追蹤按下的按鈕
    
    // 自定義按鈕視圖
    private func DirectionButton(direction: Direction, systemName: String) -> some View {
        Button(action: {
            pressedButton = direction
            move(direction)
        }) {
            Image(systemName: systemName)
                .font(.system(size: 50)) // 更大的圖標
                .foregroundColor(.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(pressedButton == direction ? Color.gray : Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    pressedButton = nil
                }
        )
    }
    
    var controlsView: some View {
        VStack(spacing: 20) { // 減少按鈕間距
            DirectionButton(direction: .up, systemName: "arrow.up.circle.fill")
            
            HStack(spacing: 60) { // 減少左右按鈕間距
                DirectionButton(direction: .left, systemName: "arrow.left.circle.fill")
                DirectionButton(direction: .right, systemName: "arrow.right.circle.fill")
            }
            
            DirectionButton(direction: .down, systemName: "arrow.down.circle.fill")
        }
        .padding(.top, 20) // 減少頂部間距
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 計時器和分數
                    HStack {
                        Text("Time: \(Int(timeRemaining))s")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("Score: \(score)")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // 遊戲區域
                    ZStack {
                        // 牆壁
                        ForEach(walls, id: \.self) { wall in
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: cellSize * scaleFactor, height: cellSize * scaleFactor)
                                .position(wall)
                        }
                        
                        // 豆子
                        ForEach(dots.indices, id: \.self) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: cellSize * scaleFactor / 3, height: cellSize * scaleFactor / 3)
                                .position(dots[index])
                        }
                        
                        // 鬼魂
                        ForEach(ghosts) { ghost in
                            Circle()
                                .fill(ghost.color)
                                .frame(width: cellSize * scaleFactor, height: cellSize * scaleFactor)
                                .position(ghost.position)
                        }
                        
                        // Pac-Man
                        PacmanShape(direction: currentDirection)
                            .fill(Color.yellow)
                            .frame(width: cellSize * scaleFactor, height: cellSize * scaleFactor)
                            .position(pacmanPosition)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .background(Color.black)
                    
                    // 控制按鈕區域
                    Spacer(minLength: 20)
                    
                    controlsView
                        .frame(height: min(geometry.size.height - geometry.size.width - 100, 200))
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
                
                // 遊戲結束或勝利提示
                if gameState == .gameOver || gameState == .victory {
                    ZStack {
                        Color.black.opacity(0.8)
                        
                        VStack(spacing: 20) {
                            Text(gameState == .victory ? "Victory!" : "Game Over")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            
                            Text("Score: \(score)")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                setupGame()
                            }) {
                                Text("Restart")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showingLeaderboard = true
                            }) {
                                Text("View Leaderboard")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView()
        }
        .onAppear {
            setupGame()
        }
    }
    
    // 移動函數
    private func move(_ direction: Direction) {
        // 如果遊戲結束或暫停，不允許移動
        guard gameState == .playing else { return }
        
        currentDirection = direction
        
        // 如果計時器未啟動，則啟動
        if pacmanTimer == nil {
            startPacmanMovement()
        }
    }
    
    // 開始 Pac-Man 移動
    private func startPacmanMovement() {
        pacmanTimer?.invalidate()
        pacmanTimer = Timer.scheduledTimer(withTimeInterval: pacmanSpeed, repeats: true) { _ in
            guard self.gameState == .playing else {
                self.pacmanTimer?.invalidate()
                self.pacmanTimer = nil
                return
            }
            
            var newPosition = self.pacmanPosition
            
            switch self.currentDirection {
            case .up: newPosition.y -= self.cellSize
            case .down: newPosition.y += self.cellSize
            case .left: newPosition.x -= self.cellSize
            case .right: newPosition.x += self.cellSize
            case .none: return
            }
            
            if self.canMove(to: newPosition) {
                self.pacmanPosition = newPosition
                self.checkCollisions()
            } else {
                // 撞牆停止
                self.currentDirection = .none
                self.pacmanTimer?.invalidate()
                self.pacmanTimer = nil
            }
        }
    }
    
    // 檢查碰撞
    private func checkCollisions() {
        // 檢查豆子收集
        if let dotIndex = dots.firstIndex(where: { dot in
            abs(dot.x - pacmanPosition.x) < cellSize/2 &&
            abs(dot.y - pacmanPosition.y) < cellSize/2
        }) {
            dots.remove(at: dotIndex)
            score += 10
            
            // 檢查勝利條件
            if dots.isEmpty {
                gameState = .victory
                endGame()
            }
        }
        
        // 檢查鬼魂碰撞
        if ghosts.contains(where: { ghost in
            abs(ghost.position.x - pacmanPosition.x) < cellSize/2 &&
            abs(ghost.position.y - pacmanPosition.y) < cellSize/2
        }) {
            gameState = .gameOver
            endGame()
        }
    }
    
    // 設置遊戲
    private func setupGame() {
        // 重置遊戲狀態
        score = 0
        timeRemaining = 180
        gameState = .playing
        currentDirection = .none
        gameStartTime = Date()
        
        // 生成隨機地圖
        generateRandomMap()
        
        // 啟動遊戲計時器
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.gameState = .gameOver
                self.endGame()
            }
        }
        
        // 啟動鬼魂移動
        startGhostMovement()
    }
    
    // 檢查位置是否在邊界內
    private func isWithinBounds(_ position: CGPoint) -> Bool {
        let maxBound = CGFloat(gridSize - 1) * cellSize
        return position.x >= 0 && 
               position.x <= maxBound &&
               position.y >= 0 && 
               position.y <= maxBound
    }
    
    // 檢查位置是否可移動
    private func canMove(to position: CGPoint) -> Bool {
        guard isWithinBounds(position) else { return false }
        
        return !walls.contains(where: { wall in
            abs(wall.x - position.x) < cellSize/2 &&
            abs(wall.y - position.y) < cellSize/2
        })
    }
    
    // 獲取可用的移動方向
    private func getAvailableDirections(from position: CGPoint) -> [Direction] {
        var availableDirections: [Direction] = []
        
        let possibleMoves: [(Direction, CGPoint)] = [
            (.up, CGPoint(x: position.x, y: position.y - cellSize)),
            (.down, CGPoint(x: position.x, y: position.y + cellSize)),
            (.left, CGPoint(x: position.x - cellSize, y: position.y)),
            (.right, CGPoint(x: position.x + cellSize, y: position.y))
        ]
        
        for (direction, newPosition) in possibleMoves {
            if canMove(to: newPosition) {
                availableDirections.append(direction)
            }
        }
        
        return availableDirections
    }
    
    // 改進迷宮生成算法
    private func generateRandomMap() {
        walls.removeAll()
        dots.removeAll()
        
        var maze = Array(repeating: Array(repeating: true, count: gridSize), count: gridSize)
        var visited = Set<CGPoint>()
        
        // 創建外圍牆
        for i in 0..<gridSize {
            maze[0][i] = false
            maze[gridSize-1][i] = false
            maze[i][0] = false
            maze[i][gridSize-1] = false
            walls.append(CGPoint(x: CGFloat(i) * cellSize, y: 0))
            walls.append(CGPoint(x: CGFloat(i) * cellSize, y: CGFloat(gridSize - 1) * cellSize))
            walls.append(CGPoint(x: 0, y: CGFloat(i) * cellSize))
            walls.append(CGPoint(x: CGFloat(gridSize - 1) * cellSize, y: CGFloat(i) * cellSize))
        }
        
        // 檢查一個位置周圍的可用路徑數量（確保不會形成死路）
        func countAccessiblePaths(_ x: Int, _ y: Int, _ tempMaze: [[Bool]]) -> Int {
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
            return directions.filter { (dx, dy) in
                let newX = x + dx
                let newY = y + dy
                return newX > 0 && newX < gridSize-1 && 
                       newY > 0 && newY < gridSize-1 && 
                       tempMaze[newY][newX]
            }.count
        }
        
        // 檢查設置牆後是否會形成封閉區域或死路
        func willCreateDeadEnd(_ x: Int, _ y: Int) -> Bool {
            if x <= 0 || x >= gridSize-1 || y <= 0 || y >= gridSize-1 {
                return false
            }
            
            var tempMaze = maze
            tempMaze[y][x] = false
            
            // 檢查周圍的空白格是否會形成死路
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
            for (dx, dy) in directions {
                let newX = x + dx
                let newY = y + dy
                if newX > 0 && newX < gridSize-1 && 
                   newY > 0 && newY < gridSize-1 && 
                   tempMaze[newY][newX] {
                    // 如果相鄰的空白格只有一條路可以走，就會形成死路
                    if countAccessiblePaths(newX, newY, tempMaze) < 2 {
                        return true
                    }
                }
            }
            
            // 檢查是否所有空白格都可以相互到達
            func dfs(_ curX: Int, _ curY: Int, _ visited: inout Set<String>) {
                visited.insert("\(curX),\(curY)")
                
                for (dx, dy) in directions {
                    let newX = curX + dx
                    let newY = curY + dy
                    if newX > 0 && newX < gridSize-1 && 
                       newY > 0 && newY < gridSize-1 && 
                       tempMaze[newY][newX] &&
                       !visited.contains("\(newX),\(newY)") {
                        dfs(newX, newY, &visited)
                    }
                }
            }
            
            // 找到第一個空白格作為起點
            var startX = -1, startY = -1
            outerLoop: for i in 1..<gridSize-1 {
                for j in 1..<gridSize-1 {
                    if tempMaze[i][j] {
                        startX = j
                        startY = i
                        break outerLoop
                    }
                }
            }
            
            if startX == -1 { return true }
            
            var visited = Set<String>()
            dfs(startX, startY, &visited)
            
            // 檢查是否有無法到達的空白格
            for i in 1..<gridSize-1 {
                for j in 1..<gridSize-1 {
                    if tempMaze[i][j] && !visited.contains("\(j),\(i)") {
                        return true
                    }
                }
            }
            
            return false
        }
        
        // 檢查一個位置是否有足夠的路徑（至少兩條）
        func hasEnoughPaths(_ x: Int, _ y: Int, _ tempMaze: [[Bool]]) -> Bool {
            let paths = countAccessiblePaths(x, y, tempMaze)
            return paths >= 2 // 確保至少有兩條路徑
        }
        
        // 修改迷宮生成函數
        func generateMaze(_ x: Int, _ y: Int) {
            visited.insert(CGPoint(x: CGFloat(x) * cellSize, y: CGFloat(y) * cellSize))
            
            // 決定是否在當前位置創建牆
            if Double.random(in: 0...1) < 0.4 && x > 1 && y > 1 {
                var tempMaze = maze
                tempMaze[y][x] = false
                
                // 確保周圍的空白格至少有兩條路徑
                let surroundingValid = [(0, 1), (1, 0), (0, -1), (-1, 0)].allSatisfy { (dx, dy) in
                    let newX = x + dx
                    let newY = y + dy
                    return newX <= 0 || newX >= gridSize-1 || 
                           newY <= 0 || newY >= gridSize-1 || 
                           !tempMaze[newY][newX] ||
                           hasEnoughPaths(newX, newY, tempMaze)
                }
                
                if surroundingValid {
                    maze[y][x] = false
                    walls.append(CGPoint(x: CGFloat(x) * cellSize, y: CGFloat(y) * cellSize))
                }
            }
            
            // 繼續生成迷宮
            let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)].shuffled()
            for (dx, dy) in directions {
                let newX = x + dx
                let newY = y + dy
                
                if newX > 0 && newX < gridSize-1 && 
                   newY > 0 && newY < gridSize-1 &&
                   !visited.contains(CGPoint(x: CGFloat(newX) * cellSize, y: CGFloat(newY) * cellSize)) {
                    generateMaze(newX, newY)
                }
            }
        }
        
        // 從起點開始生成迷宮
        generateMaze(1, 1)
        
        // 確保起點周圍區域可通行
        maze[1][1] = true
        maze[1][2] = true
        maze[2][1] = true
        
        // 移除這些位置的牆壁
        walls.removeAll { wall in
            let positions = [
                CGPoint(x: cellSize, y: cellSize),
                CGPoint(x: cellSize * 2, y: cellSize),
                CGPoint(x: cellSize, y: cellSize * 2)
            ]
            return positions.contains(wall)
        }
        
        // 生成點數，確保至少佔空白處的 3/5
        var availableSpaces = [(Int, Int)]()
        for row in 1..<gridSize-1 {
            for col in 1..<gridSize-1 {
                if maze[row][col] {
                    availableSpaces.append((col, row))
                }
            }
        }
        
        let requiredDots = Int(Double(availableSpaces.count) * 0.6)
        let selectedSpaces = availableSpaces.shuffled().prefix(requiredDots)
        
        dots = selectedSpaces.map { (x, y) in
            CGPoint(x: CGFloat(x) * cellSize, y: CGFloat(y) * cellSize)
        }
        
        // 設置遊戲角色初始位置
        pacmanPosition = CGPoint(x: cellSize, y: cellSize)
        
        // 減少鬼魂數量到2個，並調整初始位置
        let possibleGhostPositions = [
            CGPoint(x: CGFloat(gridSize-2) * cellSize, y: cellSize),
            CGPoint(x: CGFloat(gridSize-2) * cellSize, y: CGFloat(gridSize-2) * cellSize)
        ]
        
        ghosts = possibleGhostPositions.enumerated().map { index, position in
            Ghost(position: position, color: [Color.red, Color.pink][index])
        }
    }
    
    private func moveGhosts() {
        guard gameState == .playing else { return }
        
        for index in ghosts.indices {
            let currentPosition = ghosts[index].position
            let availableDirections = getAvailableDirections(from: currentPosition)
            
            if availableDirections.isEmpty { continue }
            
            var bestDirection = availableDirections[0]
            var minDistance = Double.infinity
            
            for direction in availableDirections {
                var newPosition = currentPosition
                
                switch direction {
                case .up: newPosition.y -= cellSize
                case .down: newPosition.y += cellSize
                case .left: newPosition.x -= cellSize
                case .right: newPosition.x += cellSize
                case .none: continue
                }
                
                // 確保新位置在邊界內
                guard isWithinBounds(newPosition) else { continue }
                
                // 計算到 Pac-Man 的距離
                let dx = pacmanPosition.x - newPosition.x
                let dy = pacmanPosition.y - newPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // 加入智能決策因素
                let currentDirection = ghosts[index].direction
                let directionBonus = direction == currentDirection ? 0.8 : 1.0
                let randomFactor = Double.random(in: 0.9...1.1)
                
                let adjustedDistance = distance * directionBonus * randomFactor
                
                if adjustedDistance < minDistance {
                    minDistance = adjustedDistance
                    bestDirection = direction
                }
            }
            
            // 移動鬼魂
            var newPosition = currentPosition
            switch bestDirection {
            case .up: newPosition.y -= cellSize
            case .down: newPosition.y += cellSize
            case .left: newPosition.x -= cellSize
            case .right: newPosition.x += cellSize
            case .none: continue
            }
            
            // 再次確認新位置是否可移動且在邊界內
            if isWithinBounds(newPosition) && canMove(to: newPosition) {
                ghosts[index].position = newPosition
                ghosts[index].direction = bestDirection
            }
        }
        
        checkCollisions()
    }
    
    // 開始鬼魂移動
    private func startGhostMovement() {
        ghostTimer?.invalidate()
        ghostTimer = Timer.scheduledTimer(withTimeInterval: ghostSpeed, repeats: true) { _ in
            self.moveGhosts()
        }
    }
    
    // 結束遊戲
    private func endGame() {
        // 停止所有計時器
        pacmanTimer?.invalidate()
        ghostTimer?.invalidate()
        gameTimer?.invalidate()
        
        pacmanTimer = nil
        ghostTimer = nil
        gameTimer = nil
        
        // 確保 Pac-Man 停止移動
        currentDirection = .none
        
        if gameState == .victory {
            let timeSpent = 180 - timeRemaining
            let newRecord = GameRecord(score: score, timeSpent: timeSpent, date: Date())
            GameRecordManager.shared.saveRecord(newRecord)
        }
    }
}
