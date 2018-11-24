{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*                                                                           *
*   Copyright(c) 2018 A.Koverdyaev(avk)                                     *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}

type
  TIntArrayHelper = type helper for TIntArray
  private
    function  GetLenght: SizeInt; inline;
    procedure SetLength(aValue: SizeInt); inline;
  public
    function Copy: TIntArray; inline;
    property Length: SizeInt read GetLenght write SetLength;
  end;

  TDisjointSetUnion = record
  strict private
    FList: array of SizeInt;
    function  GetSize: SizeInt; inline;
    procedure SetSize(aValue: SizeInt);
  public
    procedure Clear; inline;
    procedure Reset;
  { values related to the same subset will have the same Tag }
    function  Tag(aValue: SizeInt): SizeInt;
    function  InSameSet(L, R: SizeInt): Boolean; inline;
    function  InDiffSets(L, R: SizeInt): Boolean; inline;
  { returns True and merges L and R, if L and R related to the different subsets, False otherwise }
    function  Join(L, R: SizeInt): Boolean;
    property  Size: SizeInt read GetSize write SetSize;
  end;

  TIntValue = record
    Value: SizeInt;
    constructor Create(aValue: SizeInt);
    property Key: SizeInt read Value write Value;
  end;

  TIntHashSet = record
  strict private
  type
    TTable = specialize TGLiteIntHashTable<SizeInt, TIntValue>;
    PEntry = TTable.PEntry;

  public
  type
    TEnumerator = record
    private
      FEnum: TTable.TEnumerator;
      function  GetCurrent: SizeInt; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset; inline;
      property  Current: SizeInt read GetCurrent;
    end;

  strict private
    FTable: TTable;
    function  GetCount: SizeInt; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  ToArray: TIntArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    procedure Clear; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    function  Contains(aValue: SizeInt): Boolean; inline;
    function  Add(aValue: SizeInt): Boolean;
    function  AddAll(constref a: array of SizeInt): SizeInt;
    function  AddAll(constref s: TIntHashSet): SizeInt;
    function  Remove(aValue: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
  end;

  TIntOrdPair = packed record
  strict private
    FLess,
    FGreater: SizeInt;
  public
    class function HashCode(constref aValue: TIntOrdPair): SizeInt; static; inline;
    class function Equal(constref L, R: TIntOrdPair): Boolean; static; inline;
    constructor Create(L, R: SizeInt);
    function Key: TIntOrdPair; inline;
    property Left: SizeInt read FLess;
    property Right: SizeInt read FGreater;
  end;

  PIntOrdPair = ^TIntOrdPair;

  TIntPairSet = record
  strict private
  type
    TTable = specialize TGLiteHashTableLP<TIntOrdPair, TIntOrdPair, TIntOrdPair>;
  var
    FTable: TTable;
    function GetCount: SizeInt; inline;
  public
    procedure Clear; inline;
    function  Contains(L, R: SizeInt): Boolean; inline;
    function  Add(L, R: SizeInt): Boolean;
    function  Remove(L, R: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
  end;

  TIntNode = record
    Index,
    Data: SizeInt;
    class operator = (constref L, R: TIntNode): Boolean; inline;
    class operator <>(constref L, R: TIntNode): Boolean; inline;
    class operator > (constref L, R: TIntNode): Boolean; inline;
    class operator < (constref L, R: TIntNode): Boolean; inline;
    class operator >=(constref L, R: TIntNode): Boolean; inline;
    class operator <=(constref L, R: TIntNode): Boolean; inline;
    constructor Create(aIndex, aData: SizeInt);
  end;

  { TGBinHeapMin }

  generic TGBinHeapMin<T> = record // for internal use only
  strict private
  type
    THeap = array of T;

  var
    FHeap: THeap;
    FHandle2Index: TIntArray;
    FIndex2Handle: TIntArray;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    procedure FloatUp(aIndex: SizeInt);
    procedure SiftDown(aIndex: SizeInt);
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean;
    procedure Enqueue(aHandle: SizeInt; constref aValue: T);
    procedure Update(aHandle: SizeInt; constref aNewValue: T);
    function  Peek(aHandle: SizeInt): T; inline;
    function  HeadPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGPairHeapMin<T> = record // for internal use only
  strict private
  type
    PNode = ^TNode;
    TNode = record
      Prev,
      Child,
      Sibling: PNode;
      Data: T;
      function AddChild(aNode: PNode): PNode; inline;
    end;

    TNodeList = array of TNode;

  var
    FNodeList: TNodeList;
    FRoot: PNode;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  NewNode(constref aValue: T; aHandle: SizeInt): PNode;
    function  DequeueItem: T;
    procedure RootMerge(aNode: PNode); inline;
    procedure ExtractNode(aNode: PNode);
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static; inline;
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Dequeue: T; inline;
    procedure Enqueue(aHandle: SizeInt; constref aValue: T); inline;
    procedure Update(aHandle: SizeInt; constref aNewValue: T);
    procedure Remove(aHandle: SizeInt); inline;
    function  Peek(aHandle: SizeInt): T; inline;
    function  HeadPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGPairHeapMax<T> = record // for internal use only
  strict private
  type
    PNode = ^TNode;
    TNode = record
      Prev,
      Child,
      Sibling: PNode;
      Data: T;
      function AddChild(aNode: PNode): PNode; inline;
    end;

    TNodeList = array of TNode;

  var
    FNodeList: TNodeList;
    FRoot: PNode;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  NewNode(constref aValue: T; aHandle: SizeInt): PNode; inline;
    function  DequeueItem: T;
    procedure RootMerge(aNode: PNode); inline;
    class function  NodeMerge(L, R: PNode): PNode; static;
    class function  TwoPassMerge(aNode: PNode): PNode; static;
    class procedure CutNode(aNode: PNode); static; inline;
  public
  type
    PItem = ^T;
    constructor Create(aSize: SizeInt);
    procedure MakeEmpty; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Dequeue: T; inline;
    procedure Enqueue(aHandle: SizeInt; constref aValue: T); inline;
    procedure Update(aHandle: SizeInt; constref aNewValue: T);
    function  Peek(aHandle: SizeInt): T; inline;
    function  HeadPtr(aHandle: SizeInt): PItem; inline;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  TINodePqMin = specialize TGPairHeapMin<TIntNode>;
  TINodePqMax = specialize TGPairHeapMax<TIntNode>;

  { TGJoinableHashList for internal use only; TEntry must provide
      property Key: SizeInt and numeric field Weight }
  generic TGJoinableHashList<TEntry> = record
  strict private
  type
    TTable = specialize TGLiteIntHashTable<SizeInt, TEntry>;
  public
  type
    TEnumerator = TTable.TEnumerator;
    PEntry      = ^TEntry;

  strict private
    FTable: TTable;
    function  GetCount: SizeInt; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure Add(constref aValue: TEntry);
    procedure AddAll(constref aList: TGJoinableHashList);
    procedure Remove(aValue: SizeInt); inline;
    property  Count: SizeInt read GetCount;
  end;

  generic TGSimpleWeight<T> = record
    Weight: T;
    constructor Create(aValue: T);
  end;

  TSimpleStack = record
  strict private
    Items: TIntArray;
    Top: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
  public
    constructor Create(aSize: SizeInt);
    function  ToArray: TIntArray; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure MakeEmpty; inline;
    procedure Push(aValue: SizeInt); inline;
    function  Pop: SizeInt; inline;
    function  TryPop(out aValue: SizeInt): Boolean; inline;
    function  Peek: SizeInt; inline;
    function  TryPeek(out aValue: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
  end;
  PSimpleStack = ^TSimpleStack;

  TCostItem = record
    Index: SizeInt;
    Cost: TCost;
    class operator = (constref L, R: TCostItem): Boolean; inline;
    class operator <>(constref L, R: TCostItem): Boolean; inline;
    class operator > (constref L, R: TCostItem): Boolean; inline;
    class operator < (constref L, R: TCostItem): Boolean; inline;
    class operator >=(constref L, R: TCostItem): Boolean; inline;
    class operator <=(constref L, R: TCostItem): Boolean; inline;
    constructor Create(aIndex: SizeInt; aCost: TCost);
    property Key: SizeInt read Index;
  end;

  { TGWeightHelper }
  generic TGWeightHelper<TVertex, TWeight, TEdgeData, TEqRel> = class sealed
  public
  type
    TWeightArray  = array of TWeight;

  strict private
  class var
    CFInfWeight,
    CFNegInfWeight: TWeight;
    class constructor Init;
    class function  CreateAndFill(aValue: TWeight; aSize: SizeInt): TWeightArray; static;
    class procedure Fill(var a: TWeightArray; aValue: TWeight); static;
    class function  wMax(L, R: TWeight): TWeight; static; inline;
    class function  wMin(L, R: TWeight): TWeight; static; inline;
    class function  ExtractCycle(aRoot, aLen: SizeInt; constref aTree: TIntArray): TIntArray; static;

  public
  type
    TWeightEdge = record
      Source,
      Destination: SizeInt;
      Weight:  TWeight;
      class operator = (constref L, R: TWeightEdge): Boolean; inline;
      class operator <>(constref L, R: TWeightEdge): Boolean; inline;
      class operator > (constref L, R: TWeightEdge): Boolean; inline;
      class operator < (constref L, R: TWeightEdge): Boolean; inline;
      class operator >=(constref L, R: TWeightEdge): Boolean; inline;
      class operator <=(constref L, R: TWeightEdge): Boolean; inline;
      constructor Create(s, d: SizeInt; w: TWeight);
      function Edge: TIntEdge; inline;
    end;

    TWeightItem = record
      Index: SizeInt;
      Weight: TWeight;
      class operator = (constref L, R: TWeightItem): Boolean; inline;
      class operator <>(constref L, R: TWeightItem): Boolean; inline;
      class operator > (constref L, R: TWeightItem): Boolean; inline;
      class operator < (constref L, R: TWeightItem): Boolean; inline;
      class operator >=(constref L, R: TWeightItem): Boolean; inline;
      class operator <=(constref L, R: TWeightItem): Boolean; inline;
      constructor Create(aIndex: SizeInt; w: TWeight);
      property Key: SizeInt read Index;
    end;

    TRankItem = record
      Index: SizeInt;
      Rank,
      Weight: TWeight;
      class operator = (constref L, R: TRankItem): Boolean; inline;
      class operator <>(constref L, R: TRankItem): Boolean; inline;
      class operator > (constref L, R: TRankItem): Boolean; inline;
      class operator < (constref L, R: TRankItem): Boolean; inline;
      class operator >=(constref L, R: TRankItem): Boolean; inline;
      class operator <=(constref L, R: TRankItem): Boolean; inline;
      constructor Create(aIndex: SizeInt; aRank, aWeight: TWeight);
    end;

    TApspCell = record
      Weight: TWeight;
      Predecessor: SizeInt;
      constructor Create(aWeight: TWeight; aSource: SizeInt);
    end;

    TGraph        = specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>;
    TEstimate     = function(constref aSrc, aDst: TVertex): TWeight;
    TPairHeap     = specialize TGPairHeapMin<TWeightItem>;
    TBinHeap      = specialize TGBinHeapMin<TWeightItem>;
    TAStarHeap    = specialize TGBinHeapMin<TRankItem>;
    TEdgeArray    = array of TWeightEdge;
    TWeightMatrix = array of array of TWeight;
    TApspMatrix   = array of array of TApspCell;

    { THungarian: hungarian weighted bipartite matching algorithm }
    THungarian = record
    strict private
      FGraph: TGraph;
      FMates,
      FParents,
      FQueue: TIntArray;
      FPhi: TWeightArray;
      FWhites,
      FVisited: TBoolVector;
      FMatchCount: SizeInt;
      procedure Match(aNode, aMate: SizeInt); inline;
      procedure Init(aGraph: TGraph; constref w, g: TIntArray);
      procedure InitMax(aGraph: TGraph; constref w, g: TIntArray);
      function  FindAugmentPathMin(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
      function  FindAugmentPathMax(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
      procedure AlternatePath(aRoot: SizeInt);
      function  TryAugmentMin(var aDelta: TWeight): SizeInt;
      function  TryAugmentMax(var aDelta: TWeight): SizeInt;
      procedure CorrectPhi(aDelta: TWeight); inline;
      procedure ExecuteMin;
      procedure ExecuteMax;
      function  CreateEdges: TEdgeArray;
    public
      function  MinWeightMatching(aGraph: TGraph; constref w, g: TIntArray): TEdgeArray;
      function  MaxWeightMatching(aGraph: TGraph; constref w, g: TIntArray): TEdgeArray;
    end;

    { TBfmt: Bellman-Ford-Moore SSSP algorithm with Tarjan subtree disassembly;
      copies graph into internal representation }
    TBfmt = record
    strict private
    type
      PNode  = ^TNode;
      PArc   = ^TArc;

      TArc = record
        Target: PNode;       // pointer to target node
        Weight: TWeight;
        constructor Create(aTarget: PNode; aWeight: TWeight);
      end;

      TNode = record
      private
        FirstArc: PArc;      // pointer to first incident arc
        Weight: TWeight;
        TreePrev,
        TreeNext,
        Parent: PNode;
        Level: SizeInt;
      end;

    public
      Nodes: array of TNode;
    strict private
      FArcs: array of TArc;
      FQueue: array of PNode;
      FInQueue,
      FActive: TGraph.TBitVector;
      FGraph: TGraph;
      FNodeCount: SizeInt;
      procedure CopyGraph(aDirected: Boolean);
      procedure SsspInit(aSrc: SizeInt);
    public
      constructor Create(aGraph: TGraph; aDirected: Boolean);
      function  IndexOf(aNode: PNode): SizeInt; inline;
      procedure Sssp(aSrc: SizeInt);
    end;

    { TExactTspBB:  branch and bound exact TSP algorithm;
      Syslo, Deo, Kowalik "Discrete Optimization Algorithms: With Pascal Programs"}
    TExactTspBB = record
    strict private
      FMatrix: TWeightMatrix;
      FAheadTree,
      FBackTree,
      FCurrTour,
      FBestTour: TIntArray;
      FUpperBound,
      FInitWeight: TWeight;
      FMatrixSize: SizeInt;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCancelled: Boolean;
      procedure Init(constref m: TWeightMatrix; aTimeOut: Integer);
      function  TimeOut: Boolean; inline;
      function  Reduce(constref aRows, aCols: TIntArray; var aRowRed, aColRed: TWeightArray;
                aSize: SizeInt): TWeight;
      function  SelectBest(constref aRows, aCols: TIntArray; out aRowIdx, aColIdx: SizeInt;
                aSize: SizeInt): TWeight;
      procedure Search(aLen: SizeInt; aWeight: TWeight; constref aRows, aCols: TIntArray);
    public
      function Execute(constref m: TWeightMatrix; aTimeOut: Integer;out w: TWeight; out aExact: Boolean): TIntArray;
    end;

  { returns True if aMatch is maximal matching }
    class function  IsMaxMatching(g: TGraph; constref aMatch: TEdgeArray): Boolean; static;
  { returns True if aMatch is perfect matching }
    class function  IsPerfectMatching(g: TGraph; constref aMatch: TEdgeArray): Boolean; static;
  { Dijkstra's algorithm: single-source shortest paths problem for non-negative weights  }
    class function  DijkstraSssp(g: TGraph; aSrc: SizeInt): TWeightArray; static;
    class function  DijkstraSssp(g: TGraph; aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray; static;
  { Dijkstra's pathfinding algorithm }
    class function  DijkstraPath(g: TGraph; aSrc, aDst: SizeInt): TWeight; static;
    class function  DijkstraPath(g: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray; static;
  { A* pathfinding algorithm }
    class function  AStar(g: TGraph; aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray; static;
  { modification of Bellman-Ford-Moore algorithm(aka SPFA), faster on random graps;
    en.wikipedia.org/wiki/Shortest_Path_Faster_Algorithm }
    class function  SpfaBase(g: TGraph; aSrc: SizeInt; out aTree: TIntArray; out aWeights: TWeightArray): SizeInt;
                    static;
    class function  Spfa2Base(g: TGraph; aSrc: SizeInt; out aTree: TIntArray; out aWeights: TWeightArray): SizeInt;
                    static;
  { inplace Bellman-Ford-Moore algorithm with Tarjan subtree disassembly,
    faster negative cycle detection }
    class function  BfmtBase(g: TGraph; aSrc: SizeInt; out aParents: TIntArray; out aWeights: TWeightArray): SizeInt;
                    static;
    class function  BfmtReweight(g: TGraph; out aWeights: TWeightArray): SizeInt; static;
  { negative cycle detection }
    class function  NegCycleDetect(g: TGraph; aSrc: SizeInt): TIntArray; static;
  { BFMT single-source shortest paths problem }
    class function  BfmtSssp(g: TGraph; aSrc: SizeInt; out aWeights: TWeightArray): Boolean; static;
    class function  BfmtSssp(g: TGraph; aSrc: SizeInt; out aPaths: TIntArray; out aWeights: TWeightArray): Boolean;
                    static;
  { BFMT pathfinding }
    class function  BfmtPath(g: TGraph; aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
                    static;
  { returns True if no negative cycle found, otherwise returns False and aPaths will contain
    single element with the index of an element on negative cycle }
    class function  FloydApsp(aGraph: TGraph; out aPaths: TApspMatrix): Boolean; static;
    class function  JohnsonApsp(aGraph: TGraph; out aPaths: TApspMatrix): Boolean; static;
    class function  BfmtApsp(aGraph: TGraph; aDirect: Boolean; out aPaths: TApspMatrix): Boolean; static;
  { creates array of length aLen and fills with InfWeight }
    class function  CreateWeightArray(aLen: SizeInt): TWeightArray; static; inline;
  { creates array of length aLen and fills array with NegInfWeight }
    class function  CreateWeightArrayNI(aLen: SizeInt): TWeightArray; static; inline;
  { creates array of length aLen and fills array with ZeroWeight }
    class function  CreateWeightArrayZ(aLen: SizeInt): TWeightArray; static; inline;
  { resizes array to length aLen and fills array with aValue }
    class procedure ResizeAndFill(var a: TWeightArray; aLen: SizeInt; aValue: TWeight); static;
    class function  CreateWeightsMatrix(aGraph: TGraph): TWeightMatrix; static;
    class function  IsSquareMatrix(constref m: TWeightMatrix): Boolean; static;
  { creates square matrix, fills main diagonal with (I, ZeroWeight) and
    fills other element with corresponding weights }
    class function  CreateAPSPMatrix(aGraph: TGraph): TApspMatrix; static;
  { warning: does not checks input }
    class function  ExtractMinPath(aSrc, aDst: SizeInt; constref aMatrix: TApspMatrix): TIntArray; static;
  { returns bipartite matching of maximum cardinality and minimum weight;
    warning: does not checks if aGraph is bipartite }
    class function  MinWeightMatchingB(aGraph: TGraph; constref w, g: TIntArray): TEdgeArray; static;
  { returns bipartite matching of maximum cardinality and maximum weight;
    warning: does not checks if aGraph is bipartite }
    class function  MaxWeightMatchingB(aGraph: TGraph; constref w, g: TIntArray): TEdgeArray; static;
  { returns total weight of TS tour specified of aTour;
    warning: does not checks not matrix nor tour }
    class function  TotalTourWeight(constref m: TWeightMatrix; constref aTour: TIntArray): TWeight; static;
  { cyclic shifts path aTour so that element aSrc becomes the first;
    warning: does not checks if aSrc exist in aTour }
    class procedure NormalizeTour(var aTour: TIntArray; aSrc: SizeInt); static;
  { 2-opt local search algorithm for the traveling salesman problem;
    warning: does not checks not matrix nor path }
    class procedure Tsp2Opt(constref m: TWeightMatrix; var aPath: TIntArray; out aWeight: TWeight); static;
  { greedy TSP, best of farthest insertion starting from every vertex + 2-opt local search at the end;
    Syslo, Deo, Kowalik "Discrete Optimization Algorithms: With Pascal Programs";
    warning: does not checks matrix }
    class function  GreedyTsp(constref m: TWeightMatrix; out aWeight: TWeight): TIntArray; static;
  { greedy TSP, best of nearest neighbour + 2-opt local search starting from every vertex;
    warning: does not checks matrix}
    class function  GreedyTspNn2Opt(constref m: TWeightMatrix; out aWeight: TWeight): TIntArray; static;

    class property  InfWeight: TWeight read CFInfWeight;
    class property  NegInfWeight: TWeight read CFNegInfWeight;
  end;

  { TGCustomDotWriter: abstract writer into Graphviz dot format }
  generic TGCustomDotWriter<TVertex, TEdgeData, TEqRel> = class abstract
  public
  type
    TWriteDirection = (wdTopToBottom, wdLeftToWrite);
    TGraph          = specialize TGSparseGraph<TVertex, TEdgeData, TEqRel>;
    TOnStartWrite   = function(aGraph: TGraph): utf8string of object;
    TOnWriteVertex  = function(aGraph: TGraph; aIndex: SizeInt): utf8string of object;
    TOnWriteEdge    = function(aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string of object;

  protected
  const
    DIRECTS: array[TWriteDirection] of utf8string = ('rankdir=TB;', 'rankdir=LR;');
  var
    FGraphMark,
    FEdgeMark: utf8string;
    FDirection: TWriteDirection;
    FOnStartWrite: TOnStartWrite;
    FOnWriteVertex: TOnWriteVertex;
    FOnWriteEdge: TOnWriteEdge;
    function Graph2Dot(aGraph: TGraph): utf8string; virtual; abstract;
    function DefaultWriteEdge({%H-}aGraph: TGraph; constref aEdge: TGraph.TEdge): utf8string; virtual;
  public
    procedure SaveToStream(aGraph: TGraph; aStream: TStream);
    procedure SaveToFile(aGraph: TGraph; const aFileName: string);
    property Direction: TWriteDirection read FDirection write FDirection;
    property OnStartWrite: TOnStartWrite read FOnStartWrite write FOnStartWrite;
    property OnWriteVertex: TOnWriteVertex read FOnWriteVertex write FOnWriteVertex;
    property OnWriteEdge: TOnWriteEdge read FOnWriteEdge write FOnWriteEdge;
  end;
