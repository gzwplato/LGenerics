{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic simple undirected graphs implementation.                        *
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
unit LGSimpleGraph;

{$mode objfpc}{$H+}
{$INLINE ON}{$WARN 6058 off : }
{$WARN 5024 off : Parameter "$1" not used}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  Classes, SysUtils, DateUtils,
  LGMvMatch,
  LGUtils,
  {%H-}LGHelpers,
  LGArrayHelpers,
  LGVector,
  LGQueue,
  LGCustomGraph,
  LGStrHelpers,
  LGMiscUtils,
  LGStrConst;

type
  TLineGraph = class; //forward declaration

  { TGSimpleGraph implements simple sparse undirected graph based on adjacency lists;

      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGSimpleGraph<TVertex, TEdgeData, TEqRel> = class(specialize TGCustomGraph<TVertex, TEdgeData, TEqRel>)
  protected
  type
    TSortByDegreeHelper = specialize TGDelegatedArrayHelper<SizeInt>;

    TBPCliqueIsHelper = record // BP -> bit-parallel
    private
      FMatrix: TBoolMatrix;
      FCurrSet: TBoolVector;
      FVertices,
      FRecentBest: TIntArray;
      FOnFind: TOnFindSet;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCanceled: Boolean;
      procedure Recolor(constref aCand: TBoolVector; var aColOrd, aColors: TIntArray);//aka BB_Color
      procedure Extend(var aCand: TBoolVector); // in Bron-Kerbosch terminlogy
      procedure Extend(var aSub, aCand: TBoolVector);
      procedure FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
      procedure SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
      procedure SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
    public
    { some variant of BB-MaxClique -
        San Segundo, P, Rodriguez-Losada, D., Jimenez, A.:
          "An exact bit-parallel algorithm for the maximum clique problem",
        Patrick Prosser: "Exact Algorithms for Maximum Clique: a computational study." }
      function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    { executes MaxClique upon complement graph }
      function  MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    { something like Tomita's Cliques on bit strings, except pivot maximizing -
        Etsuji Tomitaa, Akira Tanakaa, Haruhisa Takahashi:
          "The worst-case time complexity for generating all maximal cliques and
           computational experiments. }
      procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
    { executes ListCliques upon complement graph }
      procedure ListIS(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
    end;

    TBPCliqueIsHelper256 = record // BP -> bit-parallel
    private
      FMatrix: TBitMatrix256;
      FCurrSet: TBits256;
      FVertices,
      FRecentBest: TIntArray;
      FOnFind: TOnFindSet;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCanceled: Boolean;
      procedure Recolor(constref aCand: TBits256; var aColOrd, aColors: TIntArray);
      procedure Extend(var aCand: TBits256);
      procedure Extend(var aSub, aCand: TBits256);
      procedure FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
      procedure SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
      procedure SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
    public
      function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
      function  MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
      procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
      procedure ListIS(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
    end;

    TCliqueHelper = record
    private
      FMatrix: TSkeleton;
      FCurrSet: TIntSet;
      FVertices,
      FRecentBest: TIntArray;
      FOnFind: TOnFindSet;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCanceled: Boolean;
      procedure Recolor(constref aCand: TIntSet; var aColOrd, aColors: TIntArray);
      procedure Extend(var aCand: TIntSet);
      procedure Extend(var aSub, aCand: TIntSet);
      procedure FillMatrix(aGraph: TGSimpleGraph);
      procedure SortMatrixByWidth(aGraph: TGSimpleGraph);
      procedure SortMatrixByDegree(aGraph: TGSimpleGraph);
    public
      function  MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
      procedure ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
    end;

    TBPDomSetHelper = record // BP -> bit-parallel
    private
      FMatrix: TBoolMatrix;
      FVertices,
      FRecentBest: TIntArray;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCanceled: Boolean;
      procedure FillMatrix(aGraph: TGSimpleGraph);
      procedure Extend(constref aSub, aCand: TBoolVector);
    public
      function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    end;

    TBPDomSetHelper256 = record // BP -> bit-parallel
    private
      FMatrix: TBitMatrix256;
      FVertices,
      FRecentBest: TIntArray;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCanceled: Boolean;
      procedure FillMatrix(aGraph: TGSimpleGraph);
      procedure Extend(constref aSub, aCand: TBits256);
    public
      function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    end;

    TDomSetHelper = record
    private
      FMatrix: TSkeleton;
      FRecentBest: TIntArray;
      FStartTime: TDateTime;
      FTimeOut: Integer;
      FCancel: Boolean;
      procedure Extend(constref aSub, aCand: TIntSet);
    public
      function  MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer; out aExact: Boolean): TIntArray;
    end;

  { THKMatch: Hopcroft–Karp algorithm for maximum cardinality matching
      for bipartite graph - see en.wikipedia.org/wiki/Hopcroft–Karp_algorithm }
    THKMatch = record
    private
    type
      TArc = record
        Target: SizeInt; // index of target node
      end;

      TNode = record
        FirstArc,        // index of first incident arc in arcs array
        LastArc,         // index of last incident arc in arcs array
        Distance,
        Mate: SizeInt;   // index of matched node
      end;

    const
      INF_DIST = High(SizeInt);
    var
      FNodes: array of TNode;
      FArcs: array of TArc;
      FWhites: array of SizeInt;
      FQueue: TIntArray;
      FNodeCount,
      FDummy: SizeInt;  // index of dummy node
      procedure Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
      function  Bfs: Boolean;
      function  Dfs(aRoot: SizeInt): Boolean;
      function  HopcroftKarp: TIntEdgeArray;
    public
      function  GetMaxMatch(aGraph: TGSimpleGraph; constref w, g: TIntArray): TIntEdgeArray;
    end;

    { TBfsMatch: simple BFS matching algorithm for bipartite graph }
    TBfsMatch = record
     private
       FGraph: TGSimpleGraph;
       FMates,
       FParents,
       FQueue: array of SizeInt;
       FVisited: TBitVector;
       FWhites: TBoolVector;
       FMatchCount: SizeInt;
       procedure Match(aNode, aMate: SizeInt); inline;
       procedure Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
       function  FindAugmentPath(aRoot: SizeInt): SizeInt;
       procedure AlternatePath(aRoot: SizeInt);
       procedure BfsMatch;
       function  CreateEdges: TIntEdgeArray;
     public
       function  GetMaxMatch(aGraph: TGSimpleGraph; constref w, g: TIntArray): TIntEdgeArray;
     end;

  { TEdMatch: Edmonds algorithm for maximum cardinality matching }
    TEdMatch = record
    private
      FGraph: TGSimpleGraph;
      FMates,
      FBase,
      FParents,
      FQueue: TIntArray;
      FVisited,
      FLcaUsed,
      FBlossoms: TBitVector;
      FMatchCount: SizeInt;
      procedure Match(aIndex, aMate: SizeInt); inline;
      procedure ClearBase; inline;
      procedure ClearParents; inline;
      function  Lca(L, R: SizeInt): SizeInt;
      procedure MarkPath(aValue, aBloss, aChild: SizeInt);
      function  FindAugmentPath(aRoot: SizeInt; out aLast: SizeInt): Boolean;
      procedure AlternatePath(aRoot: SizeInt);
      procedure EdMatch;
      procedure Init(aGraph: TGSimpleGraph);
    public
      function  GetMaxMatch(aGraph: TGSimpleGraph): TIntEdgeArray;
    end;

    { TPapeMatch: Pape and Conradt general matching algorithm from
      Syslo, Deo, Kowalik "Discrete Optimization Algorithms: With Pascal Programs" }
    TPapeMatch = record
    private
      FGraph: TGSimpleGraph;
      FMates,
      FGrannies,
      FQueue: TIntArray;
      FInTree: TBitVector;
      FMatchCount: SizeInt;
      procedure Match(aIndex, aMate: SizeInt); inline;
      procedure TryAugment(aRoot: SizeInt);
      procedure Init(aGraph: TGSimpleGraph);
    public
      function  GetMaxMatch(aGraph: TGSimpleGraph): TIntEdgeArray;
    end;

    { TNIMinCut: some implemenation of Nagamochi-Ibaraki minimum cut algorithm }
    TNIMinCut = record
    private
    type
      TNIEdge = record
        Target,
        Weight,
        ScanRank: SizeInt;
        Scanned: Boolean;
        constructor Create(aTarget: SizeInt; constref w: SizeInt);
        property Key: SizeInt read Target;
      end;

      PECEdge    = ^TNIEdge;
      TECAdjList = specialize TGJoinableHashList<TNIEdge>;
      TPairHeap  = specialize TGPairHeapMax<TINode>;
      TEdgeQueue = specialize TGLiteQueue<TIntPair>;

    var
      FGraph: array of TECAdjList;
      FCuts: array of TIntSet;
      FQueue: TPairHeap;
      FEdgeQueue: TEdgeQueue;
      FExistNodes,
      FInQueue: TBoolVector;
      FBestSet: TIntSet;
      FBestCut: SizeInt;
      procedure ClearMarks; inline;
      procedure Init(aGraph: TGSimpleGraph);
      procedure Init2(aGraph: TGSimpleGraph);
      procedure ShrinkEdge(aSource, aTarget: SizeInt);
      procedure ScanFirstSearch;
      procedure Shrink;
    public
      function  GetMinCut(aGraph: TGSimpleGraph): SizeInt;
      function  GetMinCut(aGraph: TGSimpleGraph; out aCut: TIntSet): SizeInt;
    end;

    TDistinctEdgeEnumerator = record
    private
      FList: PNode;
      FEnum: TAdjList.TEnumerator;
      FCurrIndex,
      FLastIndex: SizeInt;
      FEnumDone: Boolean;
      function  GetCurrent: TEdge;
    public
      function  MoveNext: Boolean;
      procedure Reset;
      property  Current: TEdge read GetCurrent;
    end;

    TDistinctEdges = record
      private
        FGraph: TGSimpleGraph;
      public
        function GetEnumerator: TDistinctEdgeEnumerator;
    end;

  const
    LISTCLIQUES_BP_CUTOFF       = 60000; //BP: bit-parallel
    COMMON_BP_CUTOFF            = 50000;
    MAXCLIQUE_BP_DENSITY_CUTOFF = 0.005;

  protected
    FCompCount: SizeInt;
    FConnected,
    FConnectedValid: Boolean;
    procedure ResetTags;
    function  SeparateTag(aIndex: SizeInt): SizeInt;
    function  SeparateJoin(L, R: SizeInt): Boolean;
    procedure ValidateConnected;
    function  GetConnected: Boolean; inline;
    function  GetDensity: Double; inline;
    procedure DoRemoveVertex(aIndex: SizeInt);
    function  DoAddEdge(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
    function  DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
    function  CreateSkeleton: TSkeleton;
    procedure AssignGraph(aGraph: TGSimpleGraph);
    procedure AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
    procedure AssignVertexList(aGraph: TGSimpleGraph; constref aList: TIntArray);
    procedure AssignTree(aGraph: TGSimpleGraph; constref aTree: TIntArray);
    procedure AssignEdges(aGraph: TGSimpleGraph; constref aEdges: TIntEdgeArray);
    function  GetSeparateGraph(aIndex: SizeInt): TGSimpleGraph;
    function  GetSeparateCount: SizeInt;
    function  CountPop(aTag: SizeInt): SizeInt;
    function  GetEccentricity(aIndex: SizeInt): SizeInt;
    function  MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
    function  CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
    function  GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetApproxMatching: TIntEdgeArray;
    function  GetApproxMatching2: TIntEdgeArray;
    function  GetMvMatching: TIntEdgeArray;
    procedure ListCliquesBP(aOnFind: TOnFindSet);
    procedure ListCliquesBP256(aOnFind: TOnFindSet);
    procedure ListCliques(aOnFind: TOnFindSet);
  { returns max independent set in bipartite graph }
    function  GetMaxIsBipartite(constref w, g: TIntArray): TIntArray;
    function  GetMaxIsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMaxIsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure ListIsBP(aOnFind: TOnFindSet);
    procedure ListIsBP256(aOnFind: TOnFindSet);
    function  GetApproxMaxIS: TIntArray;
    function  GetApproxMaxIsBP: TIntArray;
    function  GetApproxMinIS: TIntArray;
    function  GetApproxMinIsBP: TIntArray;
    function  GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    function  GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
    procedure SearchForCutPoints(aRoot: SizeInt; var aPoints: TIntVector);
    function  CutPointExists(aRoot: SizeInt): Boolean;
    procedure SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
    procedure SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
    function  BridgeExists: Boolean;
    procedure SearchForBridges(var aBridges: TIntEdgeVector);
    procedure SearchForFundamentalsCycles(out aCycles: TIntArrayVector);
    procedure SearchForFundamentalsCyclesLen(out aCycleLens: TIntVector);
    procedure FindFundamentalCyclesLen(out aCycleLens: TIntVector);
    function  CreateDegreeArray: TIntArray;
    function  CreateComplementDegreeArray: TIntArray;
    function  SortVerticesByWidth(o: TSortOrder): TIntArray;
    function  SortComplementByWidth: TIntArray;
    function  SortVerticesByDegree(o: TSortOrder): TIntArray;
    function  CmpByDegree(constref L, R: SizeInt): SizeInt;
    function  CmpIntArrayLen(constref L, R: TIntArray): SizeInt;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function MayBeEqual(L, R: TGSimpleGraph): Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    procedure Clear; override;
  { saves graph in its own binary format }
    procedure SaveToStream(aStream: TStream; aWriteVertex: TOnWriteVertex; aWriteData: TOnWriteData);
    procedure LoadFromStream(aStream: TStream; aReadVertex: TOnReadVertex; aReadData: TOnReadData);
    procedure SaveToFile(const aFileName: string; aWriteVertex: TOnWriteVertex; aWriteData: TOnWriteData);
    procedure LoadFromFile(const aFileName: string; aReadVertex: TOnReadVertex; aReadData: TOnReadData);
  { returns copy of the source graph }
    function  Clone: TGSimpleGraph;
  { returns graph of connected component that contains aVertex }
    function  SeparateGraph(constref aVertex: TVertex): TGSimpleGraph;
    function  SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
  { returns a graph consisting of vertices whose indices are contained in the array aList }
    function  SubgraphFromVertexList(constref aList: TIntArray): TGSimpleGraph;
  { returns a graph constructed from the pairs provided by the aTree,
    i.e. each element treates as pair of source - destination(value -> source, index -> destination ) }
    function  SubgraphFromTree(constref aTree: TIntArray): TGSimpleGraph;
  { returns a graph constructed from the edges provided by the aEdges }
    function  SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGSimpleGraph;
  { returns line graph constucted from self }
    function  CreateLineGraph: TLineGraph;
{**********************************************************************************************************
  structural management utilities
***********************************************************************************************************}
  { returns True and vertex index, if it is added, False if such a vertex already exists }
    function  AddVertex(constref aVertex: TVertex; out aIndex: SizeInt): Boolean;
    function  AddVertex(constref aVertex: TVertex): Boolean; inline;
  { note: vertex removing breaks validity of connected property }
    procedure RemoveVertex(constref aVertex: TVertex); inline;
    procedure RemoveVertexI(aIndex: SizeInt);
  { returns True if the edge is added, False, if such an edge already exists }
    function  AddEdge(constref aSrc, aDst: TVertex; aData: TEdgeData): Boolean;
    function  AddEdge(constref aSrc, aDst: TVertex): Boolean; inline;
    function  AddEdgeI(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean; inline;
  { returns False if there is no such edge; edge removing breaks validity of connected property }
    function  RemoveEdge(constref aSrc, aDst: TVertex): Boolean; inline;
    function  RemoveEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  Degree(constref aVertex: TVertex): SizeInt; inline;
    function  DegreeI(aIndex: SizeInt): SizeInt;
    function  Isolated(constref aVertex: TVertex): Boolean; inline;
    function  IsolatedI(aIndex: SizeInt): Boolean; inline;
    function  DistinctEdges: TDistinctEdges; inline;
  { returns the eccentricity of the aVertex within its connected component }
    function  Eccentricity(constref aVertex: TVertex): SizeInt; inline;
    function  EccentricityI(aIndex: SizeInt): SizeInt;
  { returns local clustering coefficient of the aVertex: how close its neighbours are to being a clique }
    function  LocalClustering(constref aVertex: TVertex): ValReal; inline;
    function  LocalClusteringI(aIndex: SizeInt): Double;
  { if the graph is not empty, then make graph connected, adding, if necessary, new edges
    from the vertex with the index 0; returns count of added edges }
    function  EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
  { checks whether the aDst reachable from the aSrc; each vertex reachable from itself  }
    function  PathExists(constref aSrc, aDst: TVertex): Boolean; inline;
    function  PathExistsI(aSrc, aDst: SizeInt): Boolean;
  { returns index of the connected component that contains aVertex }
    function  SeparateIndexOf(constref aVertex: TVertex): SizeInt; inline;
    function  SeparateIndexI(aIndex: SizeInt): SizeInt;
  { returns number of vertices(population) in the connected component that contains aVertex }
    function  SeparatePop(constref aVertex: TVertex): SizeInt; inline;
    function  SeparatePopI(aIndex: SizeInt): SizeInt;
    function  IsTree: Boolean;
    function  CyclomaticNumber: SizeInt;
  { checks whether the graph is a regular graph (that is, the degree of all its vertices equal);
    an empty graph is considered regular }
    function  IsRegular: Boolean;
  { checks whether exists any cycle in the same connected component as aRoot;
    if True then aCycle will contain indices of the vertices of the cycle }
    function  ContainsCycle(constref aRoot: TVertex; out aCycle: TIntArray): Boolean; inline;
    function  ContainsCycleI(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
    function  ContainsEulerianCircuit: Boolean;
  { looking for some Eulerian cycle in the first connected component along the path from the first vertex }
    function  FindEulerianCircuit(out aCircuit: TIntVector): Boolean;
  { finds a certain system of fundamental cycles of the graph;
    note: pretty costly time/memory operation }
    function  FindFundamentalCycles(out aCycles: TIntArrayVector): Boolean;
  { checks whether exists any articulation point that belong to the same connected component as aRoot }
    function  ContainsCutPoint(constref aRoot: TVertex): Boolean; inline;
    function  ContainsCutPointI(aRoot: SizeInt = 0): Boolean;
  { returns the articulation points that belong to the same connection component as aRoot, if any,
    otherwise the empty vector }
    function  FindCutPoints(constref aRoot: TVertex): TIntArray; inline;
    function  FindCutPointsI(aRoot: SizeInt = 0): TIntArray;
  { removes the articulation points that belong to the same connected component as aRoot,
    adding, if necessary, new edges; returns count of added edges }
    function  RemoveCutPoints(constref aRoot: TVertex; aOnAddEdge: TOnAddEdge): SizeInt; inline;
    function  RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
  { checks whether exists any bridge in graph }
    function  ContainsBridge: Boolean;
  { returns all bridges in the result vector, if any, otherwise the empty vector }
    function  FindBridges: TIntEdgeArray;
  { returns count of biconnected components in the same connected component as aRoot;
    the corresponding elements of the aComponents will contain  the edges of those bicomponents }
    function  FindBicomponents(constref aRoot: TVertex; out aComponents: TEdgeArrayVector): SizeInt;
    function  FindBicomponentsI(aRoot: SizeInt; out aComponents: TEdgeArrayVector): SizeInt;
  { checks whether the graph is biconnected; graph with single vertex is considered biconnected }
    function  IsBiconnected: Boolean; inline;
  { makes graph biconnected, adding, if necessary, new edges; returns count of added edges }
    function  EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;

    type
      //vertex partition
      TCut = record
        A,
        B: TIntArray;
      end;

  { returns the global minimum cut; used Nagamochi-Ibaraki algorithm }
    function  MinCut: SizeInt;
    function  MinCut(out aCut: TCut): SizeInt;
  { returns array of the edges that cross the minimum cut }
    function  CrossMinCut: TIntEdgeArray;
  { returns adjacency matrix of the complement graph;
    warning: maximum matrix size limited, see MaxBitMatrixSize }
    function  ComplementMatrix: TAdjacencyMatrix;
{**********************************************************************************************************
  spanning tree utilities
***********************************************************************************************************}
  { returns the spanning tree, which is constructed starting from aRoot;
    each element contains the index of its parent (or -1 if it is root or not connected),
    i.e. provides a pair of source - destination(Result[index] - source, index - destination) }
    function  DfsSpanningTree(constref aRoot: TVertex): TIntArray; inline;
    function  DfsSpanningTreeI(aRoot: SizeInt = 0): TIntArray;
    function  BfsSpanningTree(constref aRoot: TVertex): TIntArray; inline;
    function  BfsSpanningTreeI(aRoot: SizeInt = 0): TIntArray;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality, used Hopcroft–Karp algorithm }
    function FindMaxBipartiteMatchingHK(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function MaxBipartiteMatchingHK(constref aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality }
    function FindMaxBipartiteMatchingBfs(out aMatch: TIntEdgeArray): Boolean;
  { returns the matching of the maximum cardinality in a bipartite graph without any checks }
    function MaxBipartiteMatchingBfs(constref aWhites, aGrays: TIntArray): TIntEdgeArray;
  { returns True if graph is bipartite and aMatch is maximal matching }
    function IsMaxBipartiteMatching(constref aMatch: TIntEdgeArray): Boolean;
  { returns the approximation of the matching of the maximum cardinality in an arbitrary graph }
    function ApproxMaxMatching: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used ?Edmonds? algorithm }
    function MaxMatchingEd: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Pape-Conradt algorithm }
    function MaxMatchingPC: TIntEdgeArray;
  { returns the matching of the maximum cardinality in an arbitrary graph;
    used Micali-Vazirani algorithm }
    function MaxMatchingMV: TIntEdgeArray;
{**********************************************************************************************************
  some NP-hard problem utilities
***********************************************************************************************************}
  { lists all maximal independent sets of vertices;
    will raise exception if aOnFindSet is not assigned;
    setting aCancel to True in aOnFindSet will result in an exit from the method }
    procedure ListIndependentSets(aOnFindSet: TOnFindSet);
  { returns indices of the vertices of the some found maximal independent set of maximal cardinality;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout, the best recent solution will be returned, and aExactSolution
    will be set to False }
    function  MaxIndependentSet(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  ApproxMaxIndependentSet: TIntArray;
  { returns True if aVertexSet contains indices of the some maximal independent vertex set, False otherwise }
    function  IsMaxIndependentSet(constref aVertexSet: TIntArray): Boolean;
  { returns indices of the vertices of the some found minimum dominating set in connected graph;
    will raise exception if graph is disconnected;
    worst case time cost of exact solution O*(2^n);
    aTimeOut specifies the timeout in seconds; at the end of the timeout, the best
    recent solution will be returned, and aExactSolution will be set to False }
    function  MinDominatingSet(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  ApproxMinDominatingSet: TIntArray;
  { returns True if aVertexSet contains indices of the some minimal dominating vertex set, False otherwise }
    function  IsMinDominatingSet(constref aVertexSet: TIntArray): Boolean;
  { lists all maximal cliques;
    will raise exception if aOnFindClique is not assigned;
    setting aCancel to True in aOnFindClique will result in an exit from the method }
    procedure ListMaxCliques(aOnFindClique: TOnFindSet);
  { returns indices of the vertices of the some found maximum clique;
    worst case time cost of exact solution O*(3^n/3); aTimeOut specifies the timeout in seconds;
    at the end of the timeout, the best recent solution will be returned, and aExactSolution
    will be set to False }
    function  MaxClique(out aExactSolution: Boolean; aTimeOut: Integer = WAIT_INFINITE): TIntArray;
    function  ApproxMaxClique: TIntArray;
  { returns True if aClique contains indices of the some maximal clique, False otherwise }
    function  IsMaxClique(constref aClique: TIntArray): Boolean;
{**********************************************************************************************************
  properties
***********************************************************************************************************}
  { checks whether the cached info about connected is up-to-date }
    property  ConnectedValid: Boolean read FConnectedValid;
  { checks whether the graph is connected; an empty graph is considered disconnected }
    property  Connected: Boolean read GetConnected;
  { count of connected components }
    property  SeparateCount: SizeInt read GetSeparateCount;
    property  Density: Double read GetDensity;
  end;

  TLineGraph = class(specialize TGSimpleGraph<TIntPair, TIntValue, TIntPair>);

  { TGChart: simple outline;
      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean; }
  generic TGChart<TVertex, TEqRel> = class(specialize TGSimpleGraph<TVertex, TEmptyRec, TEqRel>)
    function  AddEdge(constref aSrc, aDst: TVertex): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  EnsureConnected: SizeInt;
    function  RemoveCutPoints(constref aRoot: TVertex): SizeInt;
    function  RemoveCutPointsI(aRoot: SizeInt): SizeInt;
    function  EnsureBiconnected: SizeInt;
    procedure SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
    procedure SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
    procedure LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
    function  SeparateGraph(constref aVertex: TVertex): TGChart;
    function  SeparateGraphI(aIndex: SizeInt): TGChart;
    function  SubgraphFromVertexList(constref aList: TIntArray): TGChart;
    function  SubgraphFromTree(constref aTree: TIntArray): TGChart;
    function  SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGChart;
    function  Clone: TGChart;
  end;

  TIntChart = class(specialize TGChart<Integer, Integer>)
  protected
    procedure WriteVertex(aStream: TStream; constref aValue: Integer);
    procedure ReadVertex(aStream: TStream; out aValue: Integer);
  public
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
    procedure LoadFromDIMACSAsciiFile(const aFileName: string);
    function  SeparateGraph(aVertex: Integer): TIntChart;
    function  SeparateGraphI(aIndex: SizeInt): TIntChart;
    function  SubgraphFromVertexList(constref aList: TIntArray): TIntChart;
    function  SubgraphFromTree(constref aTree: TIntArray): TIntChart;
    function  SubgraphFromEdges(constref aEdges: TIntEdgeArray): TIntChart;
    function  Clone: TIntChart;
  end;

  { TStrChart
    warning: SaveToStream limitation for max string length = High(SmallInt) }
  TStrChart = class(specialize TGChart<string, string>)
  protected
    procedure WriteVertex(aStream: TStream; constref aValue: string);
    procedure ReadVertex(aStream: TStream; out aValue: string);
  public
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
    function  SeparateGraph(const aVertex: string): TStrChart;
    function  SeparateGraphI(aIndex: SizeInt): TStrChart;
    function  SubgraphFromVertexList(constref aList: TIntArray): TStrChart;
    function  SubgraphFromTree(constref aTree: TIntArray): TStrChart;
    function  SubgraphFromEdges(constref aEdges: TIntEdgeArray): TStrChart;
    function  Clone: TStrChart;
  end;

  { TGWeightedGraph implements simple sparse undirected weighed graph based on adjacency lists;

      functor TEqRel must provide:
        class function HashCode([const[ref]] aValue: TVertex): SizeInt;
        class function Equal([const[ref]] L, R: TVertex): Boolean;

      TEdgeData must provide field/property/function Weight: TWeight;

      TWeight must be one of predefined numeric types;
      properties MinValue, MaxValue used as infinity weight values;
      Default(TWeight) used as zero weight value }
  generic TGWeightedGraph<TVertex, TWeight, TEdgeData, TEqRel> = class(
    specialize TGSimpleGraph<TVertex, TEdgeData, TEqRel>)
  private
  type
    TPathHelper = specialize TGWeightedPathHelper<TVertex, TWeight, TEdgeData, TEqRel>;

  public
  type
    TWeightArray = TPathHelper.TWeightArray;
    TWeightEdge  = TPathHelper.TWeightEdge;
    TEdgeArray   = array of TWeightEdge;
    TEstimate    = TPathHelper.TEstimate;

  protected
  type
    TPairingHeap = TPathHelper.TPairingHeap;
    TWeightItem  = TPathHelper.TWeightItem;
    TEdgeHelper  = specialize TGComparableArrayHelper<TWeightEdge>;
    TPairHeapMax = specialize TGPairHeapMax<TWeightItem>;

    { TKuhnMatch: Kuhn weighted matching algorithm for bipartite graph }
    TKuhnMatch = record
     private
       FGraph: TGWeightedGraph;
       FMates,
       FParents,
       FQueue: array of SizeInt;
       FPots: array of TWeight;
       FWhites,
       FVisited: TBoolVector;
       FMatchCount: SizeInt;
       procedure Match(aNode, aMate: SizeInt); inline;
       procedure ClearParents; inline;
       procedure Init(aGraph: TGWeightedGraph; constref w, g: TIntArray);
       procedure InitMax(aGraph: TGWeightedGraph; constref w, g: TIntArray);
       function  FindAugmentPath(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
       function  FindAugmentPathMax(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
       procedure AlternatePath(aRoot: SizeInt);
       function  TryMatch(var aDelta: TWeight): SizeInt;
       function  TryMatchMax(var aDelta: TWeight): SizeInt;
       procedure CorrectPots(aDelta: TWeight); inline;
       procedure KuhnMatch;
       procedure KuhnMatchMax;
       function  CreateEdges: TEdgeArray;
     public
       function  GetMinWeightMatch(aGraph: TGWeightedGraph; constref w, g: TIntArray): TEdgeArray;
       function  GetMaxWeightMatch(aGraph: TGWeightedGraph; constref w, g: TIntArray): TEdgeArray;
     end;

    TSWAdjList = specialize TGJoinableHashList<TWeightItem>;

    { TNIMinCutHelper: some implemenation of Nagamochi-Ibaraki minimum cut algorithm:
        H.Nagamochi and T.Ibaraki. "Computing Edge-Connectivity in Multigraphs and Capacitated Graphs" }
    TNIMinCutHelper = record
    private
    type
      TNiEdge = record
        Target: SizeInt;
        Weight,
        ScanRank: TWeight;
        Scanned: Boolean;
        constructor Create(aTarget: SizeInt; w: TWeight);
        property Key: SizeInt read Target;
      end;

      PNiEdge    = ^TNiEdge;
      TNiAdjList = specialize TGJoinableHashList<TNiEdge>;
      TEdgeQueue = specialize TGLiteQueue<TIntPair>;

    var
      FGraph: array of TNiAdjList;
      FCuts: array of TIntSet;
      FQueue: TPairHeapMax;
      FEdgeQueue: TEdgeQueue;
      FExistNodes,
      FInQueue: TBoolVector;
      FBestSet: TIntSet;
      FBestCut: TWeight;
      procedure ClearMarks;
      procedure Init(aGraph: TGWeightedGraph);
      procedure Init2(aGraph: TGWeightedGraph);
      procedure ShrinkEdge(aSource, aTarget: SizeInt);
      procedure ScanFirstSearch;
      procedure Shrink;
    public
      function  GetMinCut(aGraph: TGWeightedGraph): TWeight;
      function  GetMinCut(aGraph: TGWeightedGraph; out aCut: TIntSet): TWeight;
    end;

    function  GetApproxMaxWeightMatching: TEdgeArray;
    function  GetApproxMinWeightMatching: TEdgeArray;
    function  GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
    function  GetTrivialMinCut(out aCut: TWeight): Boolean;
    function  StoerWagner(out aCut: TIntSet): TWeight;
    function  CreateEdgeArray: TEdgeArray;
  public
{**********************************************************************************************************
  auxiliary utilities
***********************************************************************************************************}
    class function InfWeight: TWeight; static; inline;
    class function NegInfWeight: TWeight; static; inline;
    class function ZeroWeight: TWeight; static; inline;
    class function TotalWeight(constref aEdges: TEdgeArray): TWeight; static;
  { returns True if exists edge with negative weight }
    function ContainsNegWeightEdge: Boolean;
{**********************************************************************************************************
  class management utilities
***********************************************************************************************************}
    function SeparateGraph(constref aVertex: TVertex): TGWeightedGraph;
    function SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
    function SubgraphFromVertexList(constref aList: TIntArray): TGWeightedGraph;
    function SubgraphFromTree(constref aTree: TIntArray): TGWeightedGraph;
    function SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGWeightedGraph;
    function Clone: TGWeightedGraph;
{**********************************************************************************************************
  shortest path problem utilities
***********************************************************************************************************}

  { finds all paths of minimal weight from a given vertex to the remaining vertices in the same
    connected component(SSSP), the weights of all edges must be nonnegative;
    the result contains in the corresponding component the weight of the path to the vertex or
    InfWeight if the vertex is unreachable; used Dijkstra's algorithm  }
    function MinPathsMap(constref aSrc: TVertex): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt): TWeightArray;
  { same as above and in aPathTree returns paths }
    function MinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray): TWeightArray; inline;
    function MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
  { returns False if exists edge with negative weight, otherwise finds all paths of
    minimal weight from a given vertex to the remaining vertices in the same connected
    component(SSSP); an aWeights will contain in the corresponding component the weight of the path
    to the vertex or InfWeight if the vertex is unreachable; used SPFA algorithm  }
    function FindMinPathsMap(constref aSrc: TVertex; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
  { same as above and in aPathTree returns paths }
    function FindMinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean; inline;
    function FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray; out aWeights: TWeightArray): Boolean;
  { finds the path of minimal weight from a aSrc to aDst if it exists(pathfinding);
    the weights of all edges must be nonnegative;
    returns weight of the path or InfWeight if the vertex is unreachable; used Dijkstra's algorithm  }
    function MinPathWeight(constref aSrc, aDst: TVertex): TWeight; inline;
    function MinPathWeightI(aSrc, aDst: SizeInt): TWeight;
  { returns the vertex path of minimal weight from a aSrc to aDst, if exists, and its weight in aWeight }
    function MinPath(constref aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray; inline;
    function MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
  { returns False if exists edge with negative weight, otherwise returns the vertex path
    of minimal weight from a aSrc to aDst in aPath, if exists, and its weight in aWeight }
    function FindMinPath(constref aSrc, aDst: TVertex; out aPath: TIntArray; out aWeight: TWeight): Boolean; inline;
    function FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
  { finds the path of minimal weight from a aSrc to aDst if it exists;
    the weights of all edges must be nonnegative; used A* algorithm if aEst <> nil }
    function MinPathAStar(constref aSrc, aDst: TVertex; out aWeight: TWeight; aEst: TEstimate): TIntArray; inline;
    function MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
{**********************************************************************************************************
  minimum spanning tree utilities
***********************************************************************************************************}

  { finds a spanning tree(or spanning forest if not connected) of minimal weight, Kruskal's algorithm used }
    function MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntArray;
  { finds a spanning tree(or spanning forest if not connected) of minimal weight, Prim's algorithm used }
    function MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
{**********************************************************************************************************
  matching utilities
***********************************************************************************************************}

  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality and minimum weight;
    warning: works correctly only for integer weights }
    function FindBipartiteMinWeightMatching(out aMatch: TEdgeArray): Boolean;
  { returns False if graph is not bipartite, otherwise in aMatch returns the matching of
    the maximum cardinality and maximum weight;
    warning: works correctly only for integer weights }
    function FindBipartiteMaxWeightMatching(out aMatch: TEdgeArray): Boolean;
  { returns the approximation of the matching of the maximum cardinality and
    maximun weight in an arbitrary graph }
    function ApproxMaxWeightMatching: TEdgeArray;
  { returns the approximation of the matching of the maximum cardinality and
    minimun weight in an arbitrary graph }
    function ApproxMinWeightMatching: TEdgeArray;
{**********************************************************************************************************
  networks utilities treat the weight of the edge as its capacity
***********************************************************************************************************}

  { returns the global minimum cut; the weights of all edges must be nonnegative;
    used Stoer–Wagner algorithm }
    function MinWeightCutSW(out aCut: TCut): TWeight;
  { returns the global minimum cut; the weights of all edges must be nonnegative;
    used Nagamochi-Ibaraki algorithm }
    function MinWeightCutNI: TWeight;
    function MinWeightCutNI(out aCut: TCut): TWeight;
  { returns array of the edges that cross the minimum cut }
    function CrossMinWeightCut: TEdgeArray;
  end;

  TRealPointEdge = record
    Weight: ValReal;
    constructor Create(const aWeight: ValReal);
  end;

  TPointsChart = class(specialize TGWeightedGraph<TPoint, ValReal, TRealPointEdge, TPoint>)
  protected
    procedure OnAddEdge(constref aSrc, aDst: TPoint; aData: Pointer);
    procedure WritePoint(aStream: TStream; constref aValue: TPoint);
    procedure ReadPoint(aStream: TStream; out aValue: TPoint);
  public
    class function Distance(constref aSrc, aDst: TPoint): ValReal; static;
    function  AddEdge(constref aSrc, aDst: TPoint): Boolean;
    function  AddEdgeI(aSrc, aDst: SizeInt): Boolean;
    function  EnsureConnected: SizeInt;
    function  RemoveCutPoints(constref aRoot: TPoint): SizeInt;
    function  RemoveCutPointsI(aRoot: SizeInt): SizeInt;
    function  EnsureBiconnected: SizeInt;
    procedure SaveToStream(aStream: TStream);
    procedure LoadFromStream(aStream: TStream);
    procedure SaveToFile(const aFileName: string);
    procedure LoadFromFile(const aFileName: string);
    function  SeparateGraph(aVertex: TPoint): TPointsChart;
    function  SeparateGraphI(aIndex: SizeInt): TPointsChart;
    function  SubgraphFromVertexList(constref aList: TIntArray): TPointsChart;
    function  SubgraphFromTree(constref aTree: TIntArray): TPointsChart;
    function  SubgraphFromEdges(constref aEdges: TIntEdgeArray): TPointsChart;
    function  Clone: TPointsChart;
    function  MinPathAStar(constref aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray; inline;
    function  MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate = nil): TIntArray;
  end;

implementation
{$B-}{$COPERATORS ON}

uses
  bufstream;

{ TGSimpleGraph.TBPCliqueIsHelper }

procedure TGSimpleGraph.TBPCliqueIsHelper.Recolor(constref aCand: TBoolVector; var aColOrd, aColors: TIntArray);
var
  P, Q: TBoolVector;
  I, J, ColorClass, PCount: SizeInt;
begin
  P := aCand;
  ColorClass := 0;
  I := 0;
  PCount := P.PopCount;
  while PCount > 0 do
    begin
      Inc(ColorClass);
      Q := P;
      while Q.NonEmpty do
        begin
          J := Q.Bsf;
          P[J] := False;
          Q[J] := False;
          Q.Subtract(FMatrix[J]);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
          Dec(PCount);
        end;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.Extend(var aCand: TBoolVector);
var
  NewCand: TBoolVector;
  ColOrd, Colors: TIntArray;
  I, J, ItemCount: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCanceled := True;
          exit;
        end;
      ItemCount := aCand.PopCount;
      System.SetLength(ColOrd, ItemCount);
      System.SetLength(Colors, ItemCount);
      Recolor(aCand, ColOrd, Colors);
      for I := Pred(ItemCount) downto 0 do
        begin
          if Colors[I] + FCurrSet.PopCount <= System.Length(FRecentBest) then
            exit;
          J := ColOrd[I];
          aCand[J] := False;
          FCurrSet[FVertices[J]] := True;
          NewCand := aCand.Intersection(FMatrix[J]);
          Extend(NewCand);
          FCurrSet[FVertices[J]] := False;
        end;
    end
  else
    if FCurrSet.PopCount > System.Length(FRecentBest) then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.Extend(var aSub, aCand: TBoolVector);
var
  NewSub, NewCand: TBoolVector;
  I: SizeInt;
begin
  if FCanceled then
    exit;
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub.Bsf]) do
          begin
            aCand[I] := False;
            NewCand := aCand.Intersection(FMatrix[I]);
            NewSub := aSub.Intersection(FMatrix[I]);
            FCurrSet[FVertices[I]] := True;
            Extend(NewSub, NewCand);
            FCurrSet[FVertices[I]] := False;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCanceled);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
var
  I, J: SizeInt;
  p: PAdjList;
begin
  System.SetLength(FMatrix, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FMatrix[I].Size := aGraph.VertexCount;
      p := aGraph.AdjLists[FVertices[I]];
      for J := 0 to Pred(aGraph.VertexCount) do
        if (I <> J) and (p^.Contains(FVertices[J]) xor aComplement) then
          FMatrix[I][J] := True;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FVertices := aGraph.SortComplementByWidth
  else
    FVertices := aGraph.SortVerticesByWidth(soDesc);
  FillMatrix(aGraph, aComplement);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FVertices := aGraph.SortVerticesByDegree(soAsc)
  else
    FVertices := aGraph.SortVerticesByDegree(soDesc);
  FillMatrix(aGraph, aComplement);
end;

function TGSimpleGraph.TBPCliqueIsHelper.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBoolVector;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  SortMatrixByWidth(aGraph, False);
  FRecentBest := aGraph.ApproxMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Size := aGraph.VertexCount;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCanceled;
end;

function TGSimpleGraph.TBPCliqueIsHelper.MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBoolVector;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  SortMatrixByWidth(aGraph, True);
  FRecentBest := aGraph.ApproxMaxIndependentSet;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Size := aGraph.VertexCount;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCanceled;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
var
  Sub, Cand: TBoolVector;
begin
  SortMatrixByDegree(aGraph, False);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Size := aGraph.VertexCount;
  FOnFind := aOnFind;
  FCanceled := False;
  Extend(Sub, Cand);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper.ListIS(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
var
  Sub, Cand: TBoolVector;
begin
  SortMatrixByDegree(aGraph, True);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.Size := aGraph.VertexCount;
  FOnFind := aOnFind;
  FCanceled := False;
  Extend(Sub, Cand);
end;

{ TGSimpleGraph.TBPCliqueIsHelper256 }

procedure TGSimpleGraph.TBPCliqueIsHelper256.Recolor(constref aCand: TBits256; var aColOrd, aColors: TIntArray);
var
  P, Q: TBits256;
  I, J, ColorClass, PCount: SizeInt;
begin
  P := aCand;
  ColorClass := 0;
  I := 0;
  PCount := P.PopCount;
  while PCount > 0 do
    begin
      Inc(ColorClass);
      Q := P;
      while Q.NonEmpty do
        begin
          J := Q.Bsf;
          P[J] := False;
          Q[J] := False;
          Q.Subtract(FMatrix[J]);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
          Dec(PCount);
        end;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.Extend(var aCand: TBits256);
var
  NewCand: TBits256;
  ColOrd, Colors: TIntArray;
  I, J, ItemCount: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCanceled := True;
          exit;
        end;
      ItemCount := aCand.PopCount;
      System.SetLength(ColOrd, ItemCount);
      System.SetLength(Colors, ItemCount);
      Recolor(aCand, ColOrd, Colors);
      for I := Pred(ItemCount) downto 0 do
        begin
          if Colors[I] + FCurrSet.PopCount <= System.Length(FRecentBest) then
            exit;
          J := ColOrd[I];
          aCand[J] := False;
          FCurrSet[FVertices[J]] := True;
          NewCand := aCand.Intersection(FMatrix[J]);
          Extend(NewCand);
          FCurrSet[FVertices[J]] := False;
        end;
    end
  else
    if FCurrSet.PopCount > System.Length(FRecentBest) then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.Extend(var aSub, aCand: TBits256);
var
  NewSub, NewCand: TBits256;
  I: SizeInt;
begin
  if FCanceled then
    exit;
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub.Bsf]) do
          begin
            aCand[I] := False;
            NewCand := aCand.Intersection(FMatrix[I]);
            NewSub := aSub.Intersection(FMatrix[I]);
            FCurrSet[FVertices[I]] := True;
            Extend(NewSub, NewCand);
            FCurrSet[FVertices[I]] := False;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCanceled);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.FillMatrix(aGraph: TGSimpleGraph; aComplement: Boolean);
var
  I, J: SizeInt;
  pA: PAdjList;
begin
  System.SetLength(FMatrix, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      pA := aGraph.AdjLists[FVertices[I]];
      FMatrix[I].InitZero;
      for J := 0 to Pred(aGraph.VertexCount) do
        if (I <> J) and (pA^.Contains(FVertices[J]) xor aComplement) then
          FMatrix[I][J] := True;
    end;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.SortMatrixByWidth(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FVertices := aGraph.SortComplementByWidth
  else
    FVertices := aGraph.SortVerticesByWidth(soDesc);
  FillMatrix(aGraph, aComplement);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.SortMatrixByDegree(aGraph: TGSimpleGraph; aComplement: Boolean);
begin
  if aComplement then
    FVertices := aGraph.SortVerticesByDegree(soAsc)
  else
    FVertices := aGraph.SortVerticesByDegree(soDesc);
  FillMatrix(aGraph, aComplement);
end;

function TGSimpleGraph.TBPCliqueIsHelper256.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBits256;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  SortMatrixByWidth(aGraph, False);
  FRecentBest := aGraph.ApproxMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCanceled;
end;

function TGSimpleGraph.TBPCliqueIsHelper256.MaxIS(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TBits256;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  SortMatrixByWidth(aGraph, True);
  FRecentBest := aGraph.ApproxMaxIndependentSet;
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCanceled;
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
var
  Sub, Cand: TBits256;
begin
  SortMatrixByDegree(aGraph, False);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FOnFind := aOnFind;
  FCanceled := False;
  Extend(Sub, Cand);
end;

procedure TGSimpleGraph.TBPCliqueIsHelper256.ListIS(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
var
  Sub, Cand: TBits256;
begin
  SortMatrixByDegree(aGraph, True);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FCurrSet.InitZero;
  FOnFind := aOnFind;
  FCanceled := False;
  Extend(Sub, Cand);
end;

procedure TGSimpleGraph.TCliqueHelper.Recolor(constref aCand: TIntSet; var aColOrd, aColors: TIntArray);
var
  P, Q: TIntSet;
  I, J, ColorClass: SizeInt;
begin
  P.Assign(aCand);
  P.Reverse;
  ColorClass := 0;
  I := 0;
  while P.NonEmpty do
    begin
      Inc(ColorClass);
      Q.Assign(P);
      while Q.NonEmpty do
        begin
          J := Q.Pop;
          P.Delete(J);
          Q.Subtract(FMatrix[J]^);
          aColOrd[I] := J;
          aColors[I] := ColorClass;
          Inc(I);
        end;
    end;
end;

procedure TGSimpleGraph.TCliqueHelper.Extend(var aCand: TIntSet);
var
  NewCand: TIntSet;
  ColOrd, Colors: TIntArray;
  I, J: SizeInt;
begin
  if aCand.NonEmpty then
    begin
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCanceled := True;
          exit;
        end;
      System.SetLength(ColOrd, aCand.Count);
      System.SetLength(Colors, aCand.Count);
      Recolor(aCand, ColOrd, Colors);
      for I := Pred(aCand.Count) downto 0 do
        begin
          if Colors[I] + FCurrSet.Count <= System.Length(FRecentBest) then
            exit;
          J := ColOrd[I];
          aCand.Delete(J);
          FCurrSet.Push(FVertices[J]);
          NewCand := aCand.Intersection(FMatrix[J]^);
          Extend(NewCand);
          FCurrSet.Pop;
        end;
    end
  else
    if FCurrSet.Count > System.Length(FRecentBest) then
      FRecentBest := FCurrSet.ToArray;
end;

procedure TGSimpleGraph.TCliqueHelper.Extend(var aSub, aCand: TIntSet);
var
  NewSub, NewCand: TIntSet;
  I: SizeInt;
begin
  if FCanceled then
    exit;
  if aSub.NonEmpty then
    begin
      if aCand.NonEmpty then
        for I in aCand.Difference(FMatrix[aSub[0]]^) do
          begin
            aCand.Delete(I);
            NewCand := aCand.Intersection(FMatrix[I]^);
            NewSub := aSub.Intersection(FMatrix[I]^);
            FCurrSet.Push(FVertices[I]);
            Extend(NewSub, NewCand);
            FCurrSet.Pop;
          end;
    end
  else
    FOnFind(FCurrSet.ToArray, FCanceled);
end;

procedure TGSimpleGraph.TCliqueHelper.FillMatrix(aGraph: TGSimpleGraph);
var
  I, J: SizeInt;
  pA: PAdjList;
begin
  FMatrix := TSkeleton.Create(aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      pA := aGraph.AdjLists[FVertices[I]];
      for J := 0 to Pred(aGraph.VertexCount) do
        if (I <> J) and pA^.Contains(FVertices[J]) then
          FMatrix[I]^.Push(J);
    end;
end;

procedure TGSimpleGraph.TCliqueHelper.SortMatrixByWidth(aGraph: TGSimpleGraph);
begin
  FVertices := aGraph.SortVerticesByWidth(soDesc);
  FillMatrix(aGraph);
end;

procedure TGSimpleGraph.TCliqueHelper.SortMatrixByDegree(aGraph: TGSimpleGraph);
begin
  FVertices := aGraph.SortVerticesByDegree(soDesc);
  FillMatrix(aGraph);
end;

function TGSimpleGraph.TCliqueHelper.MaxClique(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Cand: TIntSet;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  SortMatrixByWidth(aGraph);
  FRecentBest := aGraph.ApproxMaxClique;
  Cand.InitRange(aGraph.VertexCount);
  Extend(Cand);
  Result := FRecentBest;
  aExact := not FCanceled;
end;

procedure TGSimpleGraph.TCliqueHelper.ListCliques(aGraph: TGSimpleGraph; aOnFind: TOnFindSet);
var
  Sub, Cand: TIntSet;
begin
  SortMatrixByDegree(aGraph);
  Sub.InitRange(aGraph.VertexCount);
  Cand.InitRange(aGraph.VertexCount);
  FOnFind := aOnFind;
  FCanceled := False;
  Extend(Sub, Cand);
end;

{ TGSimpleGraph.TBPDomSetHelper }

procedure TGSimpleGraph.TBPDomSetHelper.FillMatrix(aGraph: TGSimpleGraph);
var
  I, J: SizeInt;
  pA: PAdjList;
begin
  FVertices := aGraph.SortVerticesByDegree(soDesc);
  System.SetLength(FMatrix, System.Length(FVertices));
  for I := 0 to System.High(FVertices) do
    begin
      FMatrix[I].Size := System.Length(FVertices);
      pA := aGraph.AdjLists[FVertices[I]];
      for J := 0 to System.High(FVertices) do
        if (I <> J) and pA^.Contains(FVertices[J]) then
          FMatrix[I][J] := True;
    end;
end;

procedure TGSimpleGraph.TBPDomSetHelper.Extend(constref aSub, aCand: TBoolVector);
var
  NewSub, NewCand: TBoolVector;
  I, J: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.PopCount >= System.High(FRecentBest) then
        exit;
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCanceled := True;
          exit;
        end;
      I := aSub.Bsf;
      NewCand := aCand;
      NewCand[FVertices[I]] := True;
      NewSub := aSub.Difference(FMatrix[I]);
      NewSub[I] := False;
      Extend(NewSub, NewCand);
      if aCand.PopCount >= System.High(FRecentBest) then
        exit;
      NewCand[FVertices[I]] := False;
      for J in aSub.Intersection(FMatrix[I]) do
        begin
          NewCand[FVertices[J]] := True;
          NewSub := aSub.Difference(FMatrix[J]);
          NewSub[J] := False;
          Extend(NewSub, NewCand);
          if NewCand.PopCount >= System.High(FRecentBest) then
            exit;
          NewCand[FVertices[I]] := True;
          NewSub.Subtract(FMatrix[I]);
          Extend(NewSub, NewCand);
          if NewCand.PopCount >= System.Length(FRecentBest) then
            exit;
          NewCand[FVertices[I]] := False;
          NewCand[FVertices[J]] := False;
        end;
    end
  else
    if aCand.PopCount < System.Length(FRecentBest) then
      FRecentBest := aCand.ToArray;
end;

function TGSimpleGraph.TBPDomSetHelper.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Sub, Cand: TBoolVector;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  FillMatrix(aGraph);
  FRecentBest := aGraph.ApproxMinDominatingSet;
  Cand.Size := aGraph.VertexCount;
  Sub.InitRange(aGraph.VertexCount);
  Extend(Sub, Cand);
  aExact := not FCanceled;
  Result := FRecentBest;
end;

{ TGSimpleGraph.TBPDomSetHelper256 }

procedure TGSimpleGraph.TBPDomSetHelper256.FillMatrix(aGraph: TGSimpleGraph);
var
  I, J: SizeInt;
  pA: PAdjList;
begin
  FVertices := aGraph.SortVerticesByDegree(soDesc);
  System.SetLength(FMatrix, System.Length(FVertices));
  for I := 0 to Pred(System.High(FVertices)) do
    begin
      FMatrix[I].InitZero;
      pA := aGraph.AdjLists[FVertices[I]];
      for J := 0 to System.High(FVertices) do
        if (I <> J) and pA^.Contains(FVertices[J]) then
          FMatrix[I][J] := True;
    end;
end;

procedure TGSimpleGraph.TBPDomSetHelper256.Extend(constref aSub, aCand: TBits256);
var
  NewSub, NewCand: TBits256;
  I, J: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.PopCount >= System.High(FRecentBest) then
        exit;
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCanceled := True;
          exit;
        end;
      I := aSub.Bsf;
      NewCand := aCand;
      NewCand[FVertices[I]] := True;
      NewSub := aSub.Difference(FMatrix[I]);
      NewSub[I] := False;
      Extend(NewSub, NewCand);
      if aCand.PopCount >= System.High(FRecentBest) then
        exit;
      NewCand[FVertices[I]] := False;
      for J in aSub.Intersection(FMatrix[I]) do
        begin
          NewCand[FVertices[J]] := True;
          NewSub := aSub.Difference(FMatrix[J]);
          NewSub[J] := False;
          Extend(NewSub, NewCand);
          if NewCand.PopCount >= System.High(FRecentBest) then
            exit;
          NewCand[FVertices[I]] := True;
          NewSub.Subtract(FMatrix[I]);
          Extend(NewSub, NewCand);
          if NewCand.PopCount >= System.Length(FRecentBest) then
            exit;
          NewCand[FVertices[I]] := False;
          NewCand[FVertices[J]] := False;
        end;
    end
  else
    if aCand.PopCount < System.Length(FRecentBest) then
      FRecentBest := aCand.ToArray;
end;

function TGSimpleGraph.TBPDomSetHelper256.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Sub, Cand: TBits256;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCanceled := False;
  FillMatrix(aGraph);
  FRecentBest := aGraph.ApproxMinDominatingSet;
  {%H-}Cand.InitZero;
  Sub.InitRange(aGraph.VertexCount);
  Extend(Sub, Cand);
  aExact := not FCanceled;
  Result := FRecentBest;
end;

{ TGSimpleGraph.TDomSetHelper }

procedure TGSimpleGraph.TDomSetHelper.Extend(constref aSub, aCand: TIntSet);
var
  NewSub, NewCand: TIntSet;
  I, J: SizeInt;
begin
  if aSub.NonEmpty then
    begin
      if aCand.Count >= System.High(FRecentBest) then
        exit;
      if SecondsBetween(Now, FStartTime) >= FTimeOut then
        begin
          FCancel := True;
          exit;
        end;
      I := aSub[0];
      NewCand.Assign(aCand);
      NewCand.Push(I);
      NewSub := aSub.Difference(FMatrix[I]^);
      NewSub.Delete(I);
      Extend(NewSub, NewCand);
      if aCand.Count >= System.High(FRecentBest) then
        exit;
      NewCand.Pop;
      for J in aSub.Intersection(FMatrix[I]^) do
        begin
          NewCand.Push(J);
          NewSub := aSub.Difference(FMatrix[J]^);
          NewSub.Delete(J);
          Extend(NewSub, NewCand);
          if NewCand.Count >= System.High(FRecentBest) then
            exit;
          NewCand.Push(I);
          NewSub.Subtract(FMatrix[I]^);
          Extend(NewSub, NewCand);
          if NewCand.Count >= System.Length(FRecentBest) then
            exit;
          NewCand.Pop;
          NewCand.Pop;
        end;
    end
  else
    if aCand.Count < System.Length(FRecentBest) then
      FRecentBest := aCand.ToArray;
end;

function TGSimpleGraph.TDomSetHelper.MinDomSet(aGraph: TGSimpleGraph; aTimeOut: Integer;
  out aExact: Boolean): TIntArray;
var
  Sub, Cand: TIntSet;
begin
  FStartTime := Now;
  FTimeOut := aTimeOut and System.High(Integer);
  FCancel := False;
  FRecentBest := aGraph.ApproxMinDominatingSet;
  FMatrix := aGraph.CreateSkeleton;
  Sub.AssignArray(aGraph.SortVerticesByDegree(soDesc));
  Extend(Sub, Cand{%H-});
  aExact := not FCancel;
  Result := FRecentBest;
end;

{ TGSimpleGraph.THKMatch }

procedure TGSimpleGraph.THKMatch.Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
var
  CurrArcIdx: TIntArray = nil;
  Grays: TIntHashSet;
  I, J: SizeInt;
  p: PAdjItem;
begin
  FNodeCount := Succ(aGraph.VertexCount);
  FDummy := Pred(FNodeCount);
  if System.Length(w) <= System.Length(g) then
    begin
      FWhites := w;
      Grays.AddAll(g);
    end
  else
    begin
      FWhites := g;
      Grays.AddAll(w);
    end;

  System.SetLength(CurrArcIdx, FNodeCount);
  J := 0;
  for I := 0 to FNodeCount - 2 do
    begin
      CurrArcIdx[I] := J;
      if Grays.Contains(I) then
        J += Succ(aGraph.DegreeI(I))
      else
        J += aGraph.DegreeI(I);
    end;
  CurrArcIdx[Pred(FNodeCount)] := J;

  System.SetLength(FNodes, FNodeCount);
  System.SetLength(FArcs, (aGraph.EdgeCount + Grays.Count) * 2);

  for I := 0 to System.High(FNodes) do
    begin
      FNodes[I].FirstArc := CurrArcIdx[I];
      FNodes[I].Distance := 0;
      FNodes[I].Mate := FDummy;
    end;

  for I in FWhites do
    for p in aGraph.AdjLists[I]^ do
      begin
        J := p^.Destination;
        FArcs[CurrArcIdx[I]].Target := J;
        FArcs[CurrArcIdx[J]].Target := I;
        Inc(CurrArcIdx[I]);
        Inc(CurrArcIdx[J]);
      end;

  J := FDummy;
  for I in Grays do
    begin
      FArcs[CurrArcIdx[I]].Target := J;
      FArcs[CurrArcIdx[J]].Target := I;
      Inc(CurrArcIdx[I]);
      Inc(CurrArcIdx[J]);
    end;

  for I := 0 to System.High(FNodes) do
    FNodes[I].LastArc := Pred(CurrArcIdx[I]);

  CurrArcIdx := nil;
  FQueue := aGraph.CreateIntArray;
end;

function TGSimpleGraph.THKMatch.Bfs: Boolean;
var
  Curr, CurrArc, Matched, Dist: SizeInt;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  for Curr in FWhites do
    if FNodes[Curr].Mate = FDummy then
      begin
        FNodes[Curr].Distance := 0;
        FQueue[qTail] := Curr;
        Inc(qTail);
      end
    else
      FNodes[Curr].Distance := INF_DIST;

  FNodes[FDummy].Distance := INF_DIST;

  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      if FNodes[{%H-}Curr].Distance < FNodes[FDummy].Distance then
        begin
          CurrArc := FNodes[Curr].FirstArc;
          Dist := Succ(FNodes[Curr].Distance);
          while CurrArc <= FNodes[Curr].LastArc do
            begin
              Matched := FNodes[FArcs[CurrArc].Target].Mate;
              if FNodes[Matched].Distance = INF_DIST then
                begin
                  FNodes[Matched].Distance := Dist;
                  FQueue[qTail] := Matched;
                  Inc(qTail);
                end;
              Inc(CurrArc);
            end;
        end;
    end;
  Result := FNodes[FDummy].Distance <> INF_DIST;
end;

function TGSimpleGraph.THKMatch.Dfs(aRoot: SizeInt): Boolean;
var
  CurrArc, Dist, Next, Matched: SizeInt;
begin
  //todo: non-recursive dfs ???
  if aRoot = FDummy then
    exit(True);
  CurrArc := FNodes[aRoot].FirstArc;
  Dist := Succ(FNodes[aRoot].Distance);
  while CurrArc <= FNodes[aRoot].LastArc do
    begin
      Next := FArcs[CurrArc].Target;
      Matched := FNodes[Next].Mate;
      if (FNodes[Matched].Distance = Dist) and Dfs(Matched) then
        begin
          FNodes[aRoot].Mate := Next;
          FNodes[Next].Mate := aRoot;
          exit(True);
        end;
      Inc(CurrArc);
    end;
  FNodes[aRoot].Distance := INF_DIST;
  Result := False;
end;

function TGSimpleGraph.THKMatch.HopcroftKarp: TIntEdgeArray;
var
  I, J, Size: SizeInt;
begin
  Size := 0;
  while Bfs do
    for I in FWhites do
      if FNodes[I].Mate = FDummy then
        Size += Ord(Dfs(I));
  System.SetLength(Result, Size);
  J := 0;
  for I in FWhites do
    if FNodes[I].Mate <> FDummy then
      begin
        Result[J] := TIntEdge.Create(I, FNodes[I].Mate);
        Inc(J);
      end;
end;

function TGSimpleGraph.THKMatch.GetMaxMatch(aGraph: TGSimpleGraph; constref w, g: TIntArray): TIntEdgeArray;
begin
  Init(aGraph, w, g);
  Result := HopcroftKarp;
end;

{ TGSimpleGraph.TBfsMatch }

procedure TGSimpleGraph.TBfsMatch.Match(aNode, aMate: SizeInt);
begin
  FMates[aNode] := aMate;
  FMates[aMate] := aNode;
end;

procedure TGSimpleGraph.TBfsMatch.Init(aGraph: TGSimpleGraph; constref w, g: TIntArray);
var
  I: SizeInt;
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FWhites.Size := aGraph.VertexCount;
  FVisited.Size := aGraph.VertexCount;
  if System.Length(w) <= System.Length(g) then
    for I in w do
      FWhites[I] := True
  else
    for I in g do
      FWhites[I] := True;
  FMates := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  for e in aGraph.GetApproxMatching do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TBfsMatch.FindAugmentPath(aRoot: SizeInt): SizeInt;
var
  Curr, Next: SizeInt;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FVisited.ClearBits;
  FParents[aRoot] := NULL_INDEX;
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      if FWhites[Curr] then
        begin
          for p in FGraph.AdjLists[Curr]^ do
            begin
              Next := p^.Destination;
              if (FMates[Curr] = Next) or FVisited[Next] then
                continue;
              if FMates[Next] = NULL_INDEX then
                begin
                  FParents[Next] := Curr;
                  exit(Next);
                end
              else
                begin
                  FParents[Next] := Curr;
                  FQueue[qTail] := Next;
                  Inc(qTail);
                end;
            end;
        end
      else
        begin
          Next := FMates[Curr];
          FParents[Next] := Curr;
          FQueue[qTail] := Next;
          Inc(qTail);
        end;
    end;
  Result := NULL_INDEX;
end;

procedure TGSimpleGraph.TBfsMatch.AlternatePath(aRoot: SizeInt);
var
  Mate, tmp: SizeInt;
begin
  repeat
    Mate := FParents[aRoot];
    tmp := FMates[Mate];
    Match(aRoot, Mate);
    aRoot := tmp;
  until aRoot = NULL_INDEX;
end;

procedure TGSimpleGraph.TBfsMatch.BfsMatch;
var
  I, Last: SizeInt;
begin
  for I in FWhites do
    if FMates[I] = NULL_INDEX then
      begin
        Last := FindAugmentPath(I);
        if Last <> NULL_INDEX then
          begin
            AlternatePath(Last);
            Inc(FMatchCount);
          end;
      end;
end;

function TGSimpleGraph.TBfsMatch.CreateEdges: TIntEdgeArray;
var
  I, J: SizeInt;
begin
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I in FWhites do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        Inc(J);
      end;
end;

function TGSimpleGraph.TBfsMatch.GetMaxMatch(aGraph: TGSimpleGraph; constref w, g: TIntArray): TIntEdgeArray;
begin
  Init(aGraph, w, g);
  BfsMatch;
  Result := CreateEdges;
end;

{ TGSimpleGraph.TEdMatch }

procedure TGSimpleGraph.TEdMatch.Match(aIndex, aMate: SizeInt);
begin
  FMates[aIndex] := aMate;
  FMates[aMate] := aIndex;
end;

procedure TGSimpleGraph.TEdMatch.ClearBase;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBase) do
   FBase[I] := I;
end;

procedure TGSimpleGraph.TEdMatch.ClearParents;
begin
  System.FillChar(Pointer(FParents)^, System.Length(FParents) * SizeOf(SizeInt), $ff);
end;

function TGSimpleGraph.TEdMatch.Lca(L, R: SizeInt): SizeInt;
begin
  FLcaUsed.ClearBits;
  repeat
    L := FBase[L];
    FLcaUsed[L] := True;
    if FMates[L] = NULL_INDEX then
        break;
    L := FParents[FMates[L]];
  until False;
  repeat
    R := FBase[R];
    if FLcaUsed[R] then
      exit(R);
     R := FParents[FMates[R]];
  until False;
  Result := NULL_INDEX;
end;

procedure TGSimpleGraph.TEdMatch.MarkPath(aValue, aBloss, aChild: SizeInt);
begin
  while FBase[aBloss] <> aBloss do
    begin
      FBlossoms[FBase[aValue]] := True;
      FBlossoms[FBase[FMates[aValue]]] := True;
      FParents[aValue] := aChild;
      aChild := FMates[aValue];
      aValue := FParents[FMates[aValue]];
    end;
end;

function TGSimpleGraph.TEdMatch.FindAugmentPath(aRoot: SizeInt; out aLast: SizeInt): Boolean;
var
  I, Curr, Next, CurrBase: SizeInt;
  p: TGSimpleGraph.PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FVisited.ClearBits;
  ClearParents;
  ClearBase;
  FVisited[aRoot] := True;
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      for p in FGraph.AdjLists[Curr]^ do
        begin
          Next := p^.Destination;
          if (FBase[Curr] = FBase[Next]) or (FMates[Curr] = Next) then
            continue;
          if (Next = aRoot) or (FMates[Next] <> NULL_INDEX) and (FParents[FMates[Next]] <> NULL_INDEX) then
            begin
              CurrBase := Lca(Curr, Next);
              FBlossoms.ClearBits;
      	      MarkPath(Curr, CurrBase, Next);
      	      MarkPath(Next, CurrBase, Curr);
              for I := 0 to System.High(FBase) do
                if FBlossoms[FBase[I]] then
                  begin
                    FBase[I] := CurrBase;
                    if not FVisited[I] then
                      begin
                        FVisited[I] := True;
                        FQueue[qTail] := I;
                        Inc(qTail);
                      end;
                  end;
            end
          else
            if FParents[Next] = NULL_INDEX then
              begin
                FParents[Next] := Curr;
                if FMates[Next] = NULL_INDEX then
                  begin
                    aLast := Next;
                    exit(True);
                  end;
                Next := FMates[Next];
                FVisited[Next] := True;
                FQueue[qTail] := Next;
                Inc(qTail);
              end;
        end;
    end;
  Result := False;
end;

procedure TGSimpleGraph.TEdMatch.AlternatePath(aRoot: SizeInt);
var
  Mate, tmp: SizeInt;
begin
  repeat
    Mate := FParents[aRoot];
    tmp := FMates[Mate];
    Match(aRoot, Mate);
    aRoot := tmp;
  until aRoot = NULL_INDEX;
end;

procedure TGSimpleGraph.TEdMatch.EdMatch;
var
  I, Last: SizeInt;
begin
  for I := 0 to System.High(FMates) do
    if (FMates[I] = NULL_INDEX) and FindAugmentPath(I, Last) then
      begin
        AlternatePath(Last);
        Inc(FMatchCount);
      end;
end;

procedure TGSimpleGraph.TEdMatch.Init(aGraph: TGSimpleGraph);
var
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FMates := aGraph.CreateIntArray;
  FBase := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FVisited.Size := aGraph.VertexCount;
  FLcaUsed.Size := aGraph.VertexCount;
  FBlossoms.Size := aGraph.VertexCount;
  for e in aGraph.GetApproxMatching2 do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TEdMatch.GetMaxMatch(aGraph: TGSimpleGraph): TIntEdgeArray;
var
  I, J: SizeInt;
begin
  Init(aGraph);
  EdMatch;
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I := 0 to System.High(FMates) do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        FMates[FMates[I]] := NULL_INDEX;
        Inc(J);
      end;
end;

{ TGSimpleGraph.TPapeMatch }

procedure TGSimpleGraph.TPapeMatch.Match(aIndex, aMate: SizeInt);
begin
  FMates[aIndex] := aMate;
  FMates[aMate] := aIndex;
end;

procedure TGSimpleGraph.TPapeMatch.TryAugment(aRoot: SizeInt);
var
  Curr, Next, Mate, Tmp: SizeInt;
  p: PAdjItem;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FInTree.ClearBits;
  FInTree[aRoot] := True;
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      for p in FGraph.AdjLists[Curr]^ do
        if not FInTree[p^.Destination] then
          begin
            Next := p^.Destination;
            Mate := FMates[Next];
            if Mate = NULL_INDEX then
              begin
                FMates[Next] := Curr;
                repeat
                  Tmp := FMates[Curr];
                  FMates[Curr] := Next;
                  if Tmp <> NULL_INDEX then
                    begin
                      Curr := FGrannies[Curr];
                      FMates[Tmp] := Curr;
                      Next := Tmp;
                    end;
                until Tmp = NULL_INDEX;
                Inc(FMatchCount);
                exit;
              end
            else
              if Mate <> Curr then
                begin
                  if Curr <> aRoot then
                    begin
                      Tmp := FGrannies[Curr];
                      while (Tmp <> aRoot) and (Tmp <> Next) do
                        Tmp := FGrannies[Tmp];
                      if Tmp <> aRoot then
                        continue;
                    end;
                  FInTree[Next] := True;
                  FGrannies[Mate] := Curr;
                  FQueue[qTail] := Mate;
                  Inc(qTail);
                end;
          end;
    end;
end;

procedure TGSimpleGraph.TPapeMatch.Init(aGraph: TGSimpleGraph);
var
  e: TIntEdge;
begin
  FMatchCount := 0;
  FGraph := aGraph;
  FMates := aGraph.CreateIntArray;
  FGrannies := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FInTree.Size := aGraph.VertexCount;
  for e in aGraph.GetApproxMatching do
    begin
      Match(e.Source, e.Destination);
      Inc(FMatchCount);
    end;
end;

function TGSimpleGraph.TPapeMatch.GetMaxMatch(aGraph: TGSimpleGraph): TIntEdgeArray;
var
  I, J: SizeInt;
begin
  Init(aGraph);
  for I := 0 to System.High(FMates) do
    if FMates[I] = NULL_INDEX then
      TryAugment(I);
  System.SetLength(Result, FMatchCount);
  J := 0;
  for I := 0 to System.High(FMates) do
    if FMates[I] <> NULL_INDEX then
      begin
        Result[J] := TIntEdge.Create(I, FMates[I]);
        FMates[FMates[I]] := NULL_INDEX;
        Inc(J);
      end;
end;

{ TGSimpleGraph.TNIMinCut.TNIEdge }

constructor TGSimpleGraph.TNIMinCut.TNIEdge.Create(aTarget: SizeInt; constref w: SizeInt);
begin
  Target := aTarget;
  Weight := w;
end;

{ TGSimpleGraph.TNIMinCut }

procedure TGSimpleGraph.TNIMinCut.ClearMarks;
var
  I: SizeInt;
  p: TECAdjList.PEntry;
begin
  for I in FExistNodes do
    for p in FGraph[I] do
      p^.Scanned := False;
end;

procedure TGSimpleGraph.TNIMinCut.Init(aGraph: TGSimpleGraph);
var
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FGraph, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FGraph[I].EnsureCapacity(aGraph.DegreeI(I));
      for p in aGraph.AdjLists[I]^ do
        FGraph[I].Add(TNIEdge.Create(p^.Destination, 1));
    end;
  FQueue := TPairHeap.Create(aGraph.VertexCount);
  FExistNodes.InitRange(aGraph.VertexCount);
  FInQueue.Size := aGraph.VertexCount;
  FBestCut := High(SizeInt);
  FCuts := nil;
end;

procedure TGSimpleGraph.TNIMinCut.Init2(aGraph: TGSimpleGraph);
var
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FGraph, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FGraph[I].EnsureCapacity(aGraph.DegreeI(I));
      for p in aGraph.AdjLists[I]^ do
        FGraph[I].Add(TNIEdge.Create(p^.Destination, 1));
    end;
  System.SetLength(FCuts, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    FCuts[I].Add(I);
  FQueue := TPairHeap.Create(aGraph.VertexCount);
  FExistNodes.InitRange(aGraph.VertexCount);
  FInQueue.Size := aGraph.VertexCount;
  FBestCut := High(SizeInt);
end;

procedure TGSimpleGraph.TNIMinCut.ShrinkEdge(aSource, aTarget: SizeInt);
var
  I: SizeInt;
  p: TECAdjList.PEntry;
  Edge: TNIEdge;
begin
  FGraph[aSource].Remove(aTarget);
  FGraph[aTarget].Remove(aSource);
  FGraph[aSource].AddAll(FGraph[aTarget]);
  for p in FGraph[aTarget] do
    begin
      I := p^.Target;
      Edge := p^;
      FGraph[I].Remove(aTarget);
      Edge.Target := aSource;
      FGraph[I].Add(Edge);
    end;
  Finalize(FGraph[aTarget]);
  FExistNodes[aTarget] := False;
  if FCuts <> nil then
    begin
      while FCuts[aTarget].TryPop(I) do
        FCuts[aSource].Push(I);
      Finalize(FCuts[aTarget]);
    end;
end;

procedure TGSimpleGraph.TNIMinCut.ScanFirstSearch;
var
  I: SizeInt;
  p: TECAdjList.PEntry;
  Item: TINode;
begin
  ClearMarks;
  FInQueue.Join(FExistNodes);
  for I in FExistNodes do
    FQueue.Enqueue(I, TINode.Create(I, 0));
  while FQueue.Count > 1 do
    begin
      I := FQueue.Dequeue.Index;
      FInQueue[I] := False;
      for p in FGraph[I] do
        if FInQueue[p^.Target] then
          begin
            Item := FQueue.Peek(p^.Target);
            Item.Data += p^.Weight;
            FQueue.Update(p^.Target, Item);
            p^.Scanned := True;
            p^.ScanRank := Item.Data;
          end;
    end;
  Item := FQueue.Dequeue;
  FInQueue[Item.Index] := False;
  if Item.Data < FBestCut then
    begin
      FBestCut := Item.Data;
      if FCuts <> nil then
        FBestSet.Assign(FCuts[Item.Index]);
    end;
end;

procedure TGSimpleGraph.TNIMinCut.Shrink;
var
  I: SizeInt;
  p: TECAdjList.PEntry;
  Pair: TIntPair;
begin
  ScanFirstSearch;
  for I in FExistNodes do
    for p in FGraph[I] do
      if p^.Scanned and (p^.ScanRank >= FBestCut) then
        FEdgeQueue.Enqueue(TIntPair.Create(I, p^.Target));
  while FEdgeQueue.TryDequeue(Pair) do
    if FExistNodes[Pair.Left] and FExistNodes[Pair.Right] then
      ShrinkEdge(Pair.Left, Pair.Right);
end;

function TGSimpleGraph.TNIMinCut.GetMinCut(aGraph: TGSimpleGraph): SizeInt;
begin
  Init(aGraph);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
end;

function TGSimpleGraph.TNIMinCut.GetMinCut(aGraph: TGSimpleGraph; out aCut: TIntSet): SizeInt;
begin
  Init2(aGraph);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
  aCut.Assign(FBestSet);
end;

{ TGSimpleGraph.TDistinctEdgeEnumerator }

function TGSimpleGraph.TDistinctEdgeEnumerator.GetCurrent: TEdge;
begin
  Result := TEdge.Create(FCurrIndex, FEnum.Current);
end;

function TGSimpleGraph.TDistinctEdgeEnumerator.MoveNext: Boolean;
begin
  repeat
    if FEnumDone then
      begin
        if FCurrIndex >= FLastIndex then
          exit(False);
        Inc(FCurrIndex);
        FEnum := FList[FCurrIndex].AdjList.GetEnumerator;
      end;
    Result := FEnum.MoveNext;
    FEnumDone := not Result;
    if Result then
      Result := FEnum.Current^.Destination > FCurrIndex;
  until Result;
end;

procedure TGSimpleGraph.TDistinctEdgeEnumerator.Reset;
begin
  FCurrIndex := -1;
  FEnumDone := True;
end;

{ TGSimpleGraph.TDistinctEdges }

function TGSimpleGraph.TDistinctEdges.GetEnumerator: TDistinctEdgeEnumerator;
begin
  Result.FList := Pointer(FGraph.FNodeList);
  Result.FLastIndex := Pred(FGraph.VertexCount);
  Result.FCurrIndex := -1;
  Result.FEnumDone := True;
end;

{ TGSimpleGraph }

procedure TGSimpleGraph.ResetTags;
var
  I: SizeInt;
begin
  for I := 0 to Pred(VertexCount) do
    FNodeList[I].Tag := I;
end;

function TGSimpleGraph.SeparateTag(aIndex: SizeInt): SizeInt;
begin
  if FNodeList[aIndex].Tag = aIndex then
    exit(aIndex);
  Result := SeparateTag(FNodeList[aIndex].Tag);
  FNodeList[aIndex].Tag := Result;
end;

function TGSimpleGraph.SeparateJoin(L, R: SizeInt): Boolean;
begin
  L := SeparateTag(L);
  R := SeparateTag(R);
  if L = R then
    exit(False);
  if NextRandomBoolean then
    FNodeList[L].Tag := R
  else
    FNodeList[R].Tag := L;
  Result := True;
end;

procedure TGSimpleGraph.ValidateConnected;
var
  Visited: TBitVector;
  Queue: TIntQueue;
  I, Curr, Next: SizeInt;
begin
  if ConnectedValid then
    exit;
  if IsEmpty then
    begin
      FCompCount := 0;
      FConnectedValid := True;
      exit;
    end;
  Visited.Size := VertexCount;
  FCompCount := VertexCount;
  ResetTags;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Curr := I;
        Visited[Curr] := True;
        repeat
          for Next in AdjVerticesI(Curr) do
            if not Visited[Next] then
              begin
                Visited[Next] := True;
                Queue.Enqueue(Next);
                if SeparateJoin(Curr, Next) then
                  Dec(FCompCount);
              end;
        until not Queue{%H-}.TryDequeue(Curr);
      end;
  FConnected := FCompCount = 1;
  FConnectedValid := True;
end;

function TGSimpleGraph.GetConnected: Boolean;
begin
  Result := SeparateCount = 1;
end;

function TGSimpleGraph.GetDensity: Double;
begin
  if NonEmpty then
    Result := (Double(EdgeCount) * 2)/(Double(VertexCount) * Double(Pred(VertexCount)))
  else
    Result := 0.0;
end;

procedure TGSimpleGraph.DoRemoveVertex(aIndex: SizeInt);
var
  CurrEdges: TAdjList.TAdjItemArray;
  I, J: SizeInt;
begin
  FEdgeCount -= FNodeList[aIndex].AdjList.Count;
  Delete(aIndex);
  FConnectedValid := False;
  for I := 0 to Pred(VertexCount) do
    begin
      CurrEdges := FNodeList[I].AdjList.ToArray;
      FNodeList[I].AdjList.MakeEmpty;
      for J := 0 to System.High(CurrEdges) do
        begin
          if CurrEdges[J].Destination <> aIndex then
            begin
              if CurrEdges[J].Destination > aIndex then
                Dec(CurrEdges[J].Destination);
              FNodeList[I].AdjList.Add(CurrEdges[J]);
            end;
        end;
    end;
end;

function TGSimpleGraph.DoAddEdge(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
begin
  if aSrc = aDst then
    exit(False);
  Result := FNodeList[aSrc].AdjList.Add(TAdjItem.Create(aDst, aData));
  if Result then
    begin
      if FNodeList[aDst].AdjList.Add(TAdjItem.Create(aSrc, aData)) then
        begin
          Inc(FEdgeCount);
          if ConnectedValid and SeparateJoin(aSrc, aDst) then
            begin
              Dec(FCompCount);
              FConnected := FCompCount = 1;
            end;
        end
      else
        raise EGraphError.Create(SEInternalDataInconsist);
    end;
end;

function TGSimpleGraph.DoRemoveEdge(aSrc, aDst: SizeInt): Boolean;
begin
  if aSrc = aDst then
    exit(False);
  Result := FNodeList[aSrc].AdjList.Remove(aDst);
  if Result then
    begin
      FNodeList[aDst].AdjList.Remove(aSrc);
      Dec(FEdgeCount);
      FConnectedValid := False;
    end;
end;

function TGSimpleGraph.CreateSkeleton: TSkeleton;
var
  I: SizeInt;
begin
  Result := TSkeleton.Create(VertexCount);
  Result.FEdgeCount := EdgeCount;
  for I := 0 to Pred(VertexCount) do
    Result[I]^.AssignList(AdjLists[I]);
end;

procedure TGSimpleGraph.AssignGraph(aGraph: TGSimpleGraph);
var
  I: SizeInt;
begin
  Clear;
  FCount := aGraph.VertexCount;
  FEdgeCount := aGraph.EdgeCount;
  FCompCount := aGraph.FCompCount;
  FTitle := aGraph.Title;
  FConnected := aGraph.Connected;
  FConnectedValid := aGraph.ConnectedValid;
  if aGraph.NonEmpty then
    begin
      FChainList := System.Copy(aGraph.FChainList);
      System.SetLength(FNodeList, System.Length(aGraph.FNodeList));
      for I := 0 to Pred(VertexCount) do
        FNodeList[I].Assign(aGraph.FNodeList[I]);
    end;
end;

procedure TGSimpleGraph.AssignSeparate(aGraph: TGSimpleGraph; aIndex: SizeInt);
var
  v: TIntArray;
  I, J, Tag: SizeInt;
begin
  System.SetLength(v, aGraph.SeparatePopI(aIndex));
  Tag := aGraph.SeparateTag(aIndex);
  J := 0;
  for I := 0 to Pred(aGraph.VertexCount) do
    if aGraph.FNodeList[I].Tag = Tag then
      begin
        v[J] := I;
        Inc(J);
      end;
  AssignVertexList(aGraph, v);
end;

procedure TGSimpleGraph.AssignVertexList(aGraph: TGSimpleGraph; constref aList: TIntArray);
var
  vSet: TIntHashSet;
  I, J: SizeInt;
begin
  vSet.AddAll(aList);
  Clear;
  for I in vSet do
    for J in aGraph.AdjVerticesI(I) do
      if vSet.Contains(J) then
        AddEdge(aGraph[I], aGraph[J], aGraph.GetEdgeDataPtr(I, J)^);
end;

procedure TGSimpleGraph.AssignTree(aGraph: TGSimpleGraph; constref aTree: TIntArray);
var
  I, Src: SizeInt;
begin
  Clear;
  for I := 0 to Pred(System.Length(aTree)) do
    begin
      Src := aTree[I];
      if Src <> -1 then
        AddEdge(aGraph[Src], aGraph[I], aGraph.GetEdgeDataPtr(Src, I)^);
    end;
end;

procedure TGSimpleGraph.AssignEdges(aGraph: TGSimpleGraph; constref aEdges: TIntEdgeArray);
var
  e: TIntEdge;
begin
  Clear;
  for e in aEdges do
    AddEdge(aGraph[e.Source], aGraph[e.Destination], aGraph.GetEdgeDataPtr(e.Source, e.Destination)^);
end;

function TGSimpleGraph.GetSeparateGraph(aIndex: SizeInt): TGSimpleGraph;
var
  I, J: SizeInt;
  d: TEdgeData;
begin
  Result := TGSimpleGraph.Create;
  J := SeparateTag(aIndex);
  for I := 0 to Pred(VertexCount) do
    if SeparateTag(I) = J then
       Result.AddVertex(Items[I]);
  for I := 0 to Pred(Result.VertexCount) do
    for J := Succ(I) to Pred(Result.VertexCount) do
      if Adjacent(Result[I], Result[J]) then
        begin
          if not GetEdgeData(Result[I], Result[J], d) then
            raise EGraphError.Create(SEInternalDataInconsist);
          Result.AddEdgeI(I, J, d);
        end;
end;

function TGSimpleGraph.GetSeparateCount: SizeInt;
begin
  if not ConnectedValid then
    ValidateConnected;
  Result := FCompCount;
end;

function TGSimpleGraph.CountPop(aTag: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  Result := 0;
  for I := 0 to Pred(VertexCount) do
    Result += Ord(SeparateTag(I) = aTag);
end;

function TGSimpleGraph.GetEccentricity(aIndex: SizeInt): SizeInt;
var
  Queue: TIntQueue;
  Dist: TIntArray;
  Next, d: SizeInt;
begin
  Dist := CreateIntArray;
  Dist[aIndex] := 0;
  Result := 0;
  repeat
    for Next in AdjVerticesI(aIndex) do
      if Dist[Next] = -1 then
        begin
          Queue.Enqueue(Next);
          d := Succ(Dist[aIndex]);
          if Result < d then
            Result := d;
          Dist[Next] := d;
        end;
  until not Queue{%H-}.TryDequeue(aIndex);
end;

function TGSimpleGraph.MakeConnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  I: SizeInt;
  d: TEdgeData;
begin
  Result := 0;
  d := DefaultEdgeData;
  for I := 1 to Pred(VertexCount) do
    if SeparateTag(0) <> SeparateTag(I) then
      begin
        if Assigned(aOnAddEdge) then
          aOnAddEdge(FNodeList[0].Vertex, FNodeList[I].Vertex, @d);
        AddEdgeI(0, I, d);
        Inc(Result);
      end;
end;

function TGSimpleGraph.CycleExists(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
var
  Stack: TIntStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  Next: SizeInt;
begin
  Visited.Size := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  Visited[aRoot] := True;
  {%H-}Stack.Push(aRoot);
  while Stack.TryPeek(aRoot) do
    if AdjEnums[aRoot].MoveNext then
      begin
        Next := AdjEnums[aRoot].Current;
        if not Visited[Next] then
          begin
            Visited[Next] := True;
            Parents[Next] := aRoot;
            Stack.Push(Next);
          end
        else
          if Parents[aRoot] <> Next then
            begin
              aCycle := TreePathFromTo(Parents, Next, aRoot);
              exit(True);
            end;
      end
    else
      Stack.Pop;
  Result := False;
end;

function TGSimpleGraph.GetMaxCliqueBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxCliqueBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxClique(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TCliqueHelper;
begin
  Result := Helper.MaxClique(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetApproxMatching: TIntEdgeArray;
var
  Nodes: TIntArray;
  Matched: TBitVector;
  CurrPos, Size, Curr, Next: SizeInt;
  p: PAdjItem;
begin
  Nodes := SortVerticesByDegree(soAsc);
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  CurrPos := 0;
  Size := 0;
  while CurrPos < VertexCount do
    begin
      if not Matched[Nodes[CurrPos]] then
        begin
          Curr := Nodes[CurrPos];
          Next := NULL_INDEX;
          for p in AdjLists[Curr]^ do // find adjacent non matched node
            if not Matched[p^.Destination] then
              begin
                Next := p^.Destination;
                break;
              end;
          if Next <> NULL_INDEX then // node found
            begin
              Matched[Curr] := True;
              Matched[Next] := True;
              if System.Length(Result) = Size then
                System.SetLength(Result, Size shl 1);
              Result[Size] := TIntEdge.Create(Curr, Next);
              Inc(Size);
            end;
        end;
      Inc(CurrPos);
    end;
  System.SetLength(Result, Size);
end;

function TGSimpleGraph.GetApproxMatching2: TIntEdgeArray;
var
  Nodes: TINodeQueue;
  Matched: TBitVector;
  Node: TINode;
  Size, I, Deg, s, d: SizeInt;
  p: PAdjItem;
begin
  Nodes := TINodeQueue.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    {%H-}Nodes.Enqueue(I, TINode.Create(I, DegreeI(I)));
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  Size := 0;
  while Nodes.TryDequeue(Node) do
    if not Matched[{%H-}Node.Index] then
      begin
        s := Node.Index;
        d := NULL_INDEX;
        Deg := VertexCount;
        for p in AdjLists[s]^ do // find adjacent node with min degree
          begin
            I := p^.Destination;
            if not Matched[I] then
              begin
                Node := Nodes.Peek(I);
                if  Node.Data < Deg then
                  begin
                    Deg := Node.Data;
                    d := I;
                  end;
                Dec(Node.Data);
                Nodes.Update(I, Node);
              end;
          end;
        if d <> NULL_INDEX then // node found
          begin
            for p in AdjLists[d]^ do
              begin
                I := p^.Destination;
                if (I <> s) and not Matched[I] then
                  begin
                    Node := Nodes.Peek(I);
                    Dec(Node.Data);
                    Nodes.Update(I, Node);
                  end;
              end;
            Matched[s] := True;
            Matched[d] := True;
            Nodes.Remove(d);
            if System.Length(Result) = Size then
              System.SetLength(Result, Size shl 1);
            Result[Size] := TIntEdge.Create(s, d);
            Inc(Size);
          end;
      end;
  System.SetLength(Result, Size);
end;

function TGSimpleGraph.GetMvMatching: TIntEdgeArray;
var
  e: TEdge;
  ie: TIntEdge;
  Nodes: LGMvMatch.TNodes;
  Edgs: LGMvMatch.TEdges;
  I, J, Matched, NodeCount, Mate: SizeInt;
begin
  Matched := 0;
  NodeCount := VertexCount;
  System.SetLength(Nodes, NodeCount);
  for I := 0 to Pred(NodeCount) do
    begin
      Nodes[I].Mate := nil;
      Nodes[I].FirstEdge := nil;
    end;

  for ie in GetApproxMatching2 do
    begin
      Nodes[ie.Source].Mate := @Nodes[ie.Destination];
      Nodes[ie.Destination].Mate := @Nodes[ie.Source];
      Inc(Matched);
    end;

  System.SetLength(Edgs, EdgeCount);
  I := 0;
  for e in DistinctEdges do
    begin
      Edgs[I].Node1 := @Nodes[e.Source];
      Edgs[I].Next1 := Nodes[e.Source].FirstEdge;
      Nodes[e.Source].FirstEdge := @Edgs[I];
      Edgs[I].Node2 := @Nodes[e.Destination];
      Edgs[I].Next2 := Nodes[e.Destination].FirstEdge;
      Nodes[e.Destination].FirstEdge := @Edgs[I];

      if Nodes[e.Source].Matched and (Nodes[e.Source].Mate = @Nodes[e.Destination]) then
        begin
          Nodes[e.Source].MatchedEdge := @Edgs[I];
          Nodes[e.Destination].MatchedEdge := @Edgs[I];
        end;

      Inc(I);
    end;

  LGMvMatch.Match(Nodes, Edgs, Matched);
  Edgs := nil;

  System.SetLength(Result, Matched);
  J := 0;
  for I := 0 to System.High(Nodes) do
    if Nodes[I].Matched then
      begin
        Mate := SizeInt(Nodes[I].Mate - LGMvMatch.PNode(Nodes));
        Result[J] := TIntEdge.Create(I, Mate);
        Nodes[Mate].Mate := nil;
        Inc(J);
      end;
end;

procedure TGSimpleGraph.ListCliquesBP(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliquesBP256(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListCliques(Self, aOnFind);
end;

procedure TGSimpleGraph.ListCliques(aOnFind: TOnFindSet);
var
  Helper: TCliqueHelper;
begin
  Helper.ListCliques(Self, aOnFind);
end;

function TGSimpleGraph.GetMaxIsBipartite(constref w, g: TIntArray): TIntArray;
var
  Helper: THKMatch;
  Lefts, LeftsVisit, LeftsFree, RightsUnvisit: TBoolVector;
  Match: TIntArray;
  e: TIntEdge;
  Stack: TIntStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  I, Curr, Next: SizeInt;
  CurrInLefts: Boolean;
begin
  Lefts.Size := VertexCount;
  LeftsVisit.Size := VertexCount;
  LeftsFree.Size := VertexCount;
  RightsUnvisit.Size := VertexCount;
  if System.Length(w) < System.Length(g) then
    begin
      for I in w do
        begin
          Lefts[I] := True;
          LeftsFree[I] := True;
        end;
      for I in g do
        RightsUnvisit[I] := True;
    end
  else
    if System.Length(w) > System.Length(g) then
      begin
        for I in g do
          begin
            Lefts[I] := True;
            LeftsFree[I] := True;
          end;
        for I in w do
          RightsUnvisit[I] := True;
      end
    else
      exit(w); ////

  Match := CreateIntArray;
  for e in Helper.GetMaxMatch(Self, w, g) do
    begin
      LeftsFree[e.Source] := False;
      LeftsFree[e.Destination] := False;
      Match[e.Source] := e.Destination;
      Match[e.Destination] := e.Source;
    end;

  //find nodes that not belong min vertex cover
  Visited.Size := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  for I in LeftsFree do
    begin
      {%H-}Stack.Push(I);
      Visited[I] := True;
      while Stack.TryPeek(Curr) do
        begin
          CurrInLefts := Lefts[Curr];
          if AdjEnums[Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  if CurrInLefts xor (Match[Curr] = Next) then
                    Stack.Push(Next);
                end;
            end
          else
            begin
              Stack.Pop;
              if CurrInLefts then
                LeftsVisit[Curr] := True
              else
                RightsUnvisit[Curr] := False;
            end;
        end;
    end;

  Match := nil;
  Lefts.Size := 0;
  LeftsFree.Size := 0;

  System.SetLength(Result, LeftsVisit.PopCount + RightsUnvisit.PopCount);
  I := 0;
  for Curr in LeftsVisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
  for Curr in RightsUnvisit do
    begin
      Result[I] := Curr;
      Inc(I);
    end;
end;

function TGSimpleGraph.GetMaxIsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMaxIsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPCliqueIsHelper256;
begin
  Result := Helper.MaxIS(Self, aTimeOut, aExact);
end;

procedure TGSimpleGraph.ListIsBP(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper;
begin
  Helper.ListIS(Self, aOnFind);
end;

procedure TGSimpleGraph.ListIsBP256(aOnFind: TOnFindSet);
var
  Helper: TBPCliqueIsHelper256;
begin
  Helper.ListIS(Self, aOnFind);
end;

function TGSimpleGraph.GetApproxMaxIS: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MinPop := VertexCount;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetApproxMaxIsBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MinPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MinPop := VertexCount;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop < MinPop then
            begin
              MinPop := CurrPop;
              J := I;
            end;
        end;
      Cand[J] := False;
      Cand.Subtract(Matrix[J]);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetApproxMinIS: TIntArray;
var
  Cand, Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionCount(AdjLists[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(AdjLists[J]);
      Cand.Delete(J);
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetApproxMinIsBP: TIntArray;
var
  Matrix: TBoolMatrix;
  Cand: TBoolVector;
  Stack: TIntSet;
  I, J, CurrPop, MaxPop: SizeInt;
begin
  Matrix := CreateBoolMatrix;
  Cand.InitRange(VertexCount);
  while Cand.NonEmpty do
    begin
      J := 0;
      MaxPop := 0;
      for I in Cand do
        begin
          CurrPop := Succ(Cand.IntersectionPop(Matrix[I]));
          if CurrPop > MaxPop then
            begin
              MaxPop := CurrPop;
              J := I;
            end;
        end;
      Cand.Subtract(Matrix[J]);
      Cand[J] := False;
      {%H-}Stack.Push(J);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.GetMdsBP(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMdsBP256(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TBPDomSetHelper256;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

function TGSimpleGraph.GetMds(aTimeOut: Integer; out aExact: Boolean): TIntArray;
var
  Helper: TDomSetHelper;
begin
  Result := Helper.MinDomSet(Self, aTimeOut, aExact);
end;

procedure TGSimpleGraph.SearchForCutPoints(aRoot: SizeInt; var aPoints: TIntVector);
var
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          aPoints.Add(Curr);
      end;
  if ChildCount > 1 then
    aPoints.Add(aRoot);
end;

function TGSimpleGraph.CutPointExists(aRoot: SizeInt): Boolean;
var
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          exit(True);
      end;
  Result := ChildCount > 1;
end;

procedure TGSimpleGraph.SearchForBiconnect(aRoot: SizeInt; var aEdges: TIntEdgeVector);
var
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents, Across: TIntArray;
  Counter, Curr, Next: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Across := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              if Across[Curr] = -1 then
                Across[Curr] := Next;
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Stack.Push(Next);
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              LowPt[Curr] := PreOrd[Next];
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if LowPt[Next] >= PreOrd[Curr] then
          begin
            if Next = Across[Curr] then
              begin
                if Curr <> aRoot then
                  aEdges.Add(TIntEdge.Create(Parents[Curr], Next));
              end
            else
              aEdges.Add(TIntEdge.Create(Across[Curr], Next));
          end;
      end;
end;

procedure TGSimpleGraph.SearchForBicomponent(aRoot: SizeInt; var aComp: TEdgeArrayVector);
var
  Stack: TIntStack;
  EdgeStack: TIntEdgeVector;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, ChildCount, I: SizeInt;
  e: TIntEdge;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  PreOrd[aRoot] := 0;
  LowPt[aRoot] := 0;
  {%H-}Stack.Push(aRoot);
  Counter := 1;
  ChildCount := 0;
  while Stack.TryPeek(Curr) do
    if AdjEnums[{%H-}Curr].MoveNext then
      begin
        Next := AdjEnums[Curr].Current;
        if Next <> Parents[Curr] then
          if PreOrd[Next] = -1 then
            begin
              Parents[Next] := Curr;
              PreOrd[Next] := Counter;
              LowPt[Next] := Counter;
              Inc(Counter);
              Inc(ChildCount, Ord(Curr = aRoot));
              Stack.Push(Next);
              EdgeStack.Add(TIntEdge.Create(Curr, Next));
            end
          else
            if LowPt[Curr] > PreOrd[Next] then
              begin
                LowPt[Curr] := PreOrd[Next];
                EdgeStack.Add(TIntEdge.Create(Curr, Next));
              end;
      end
    else
      begin
        Stack.Pop;
        Next := Curr;
        Curr := Parents[Curr];
        if LowPt[Curr] > LowPt[Next] then
          LowPt[Curr] := LowPt[Next];
        if (LowPt[Next] >= PreOrd[Curr]) and (Curr <> aRoot) then
          begin
            I := EdgeStack.Count;
            repeat
              Dec(I);
              e := EdgeStack[I];
            until (e.Source = Curr) or (e.Destination = Next);
            aComp.Add(EdgeStack.ExtractAll(I, EdgeStack.Count - I));
          end;
      end;
  if ChildCount > 1 then
    begin
      I := EdgeStack.Count;
      repeat
        Dec(I);
        e := EdgeStack[I];
      until e.Source = aRoot;
      aComp.Add(EdgeStack.ExtractAll(I, EdgeStack.Count - I));
    end;
  if EdgeStack.NonEmpty then
    aComp.Add(EdgeStack.ToArray);
end;

function TGSimpleGraph.BridgeExists: Boolean;
var
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              Next := Curr;
              Curr := Parents[Curr];
              if LowPt[Curr] > LowPt[Next] then
                LowPt[Curr] := LowPt[Next];
              if LowPt[Next] > PreOrd[Curr] then
                exit(True);
            end;
      end;
  Result := False;
end;

procedure TGSimpleGraph.SearchForBridges(var aBridges: TIntEdgeVector);
var
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  LowPt, PreOrd, Parents: TIntArray;
  Counter, Curr, Next, I: SizeInt;
begin
  AdjEnums := CreateAdjEnumArray;
  LowPt := CreateIntArray;
  PreOrd := CreateIntArray;
  Parents := CreateIntArray;
  Counter := 0;
  for I := 0 to Pred(VertexCount) do
    if PreOrd[I] = -1 then
      begin
        PreOrd[I] := Counter;
        LowPt[I] := Counter;
        Inc(Counter);
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if Next <> Parents[Curr] then
                if PreOrd[Next] = -1 then
                  begin
                    Parents[Next] := Curr;
                    PreOrd[Next] := Counter;
                    LowPt[Next] := Counter;
                    Inc(Counter);
                    Stack.Push(Next);
                  end
                else
                  if LowPt[Curr] > PreOrd[Next] then
                    LowPt[Curr] := PreOrd[Next];
            end
          else
            begin
              Stack.Pop;
              Next := Curr;
              Curr := Parents[Curr];
              if LowPt[Curr] > LowPt[Next] then
                LowPt[Curr] := LowPt[Next];
              if LowPt[Next] > PreOrd[Curr] then
                aBridges.Add(TIntEdge.Create(Curr, Next));
            end;
      end;
end;

procedure TGSimpleGraph.SearchForFundamentalsCycles(out aCycles: TIntArrayVector);
var
  Stack: TIntStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Curr, Next: SizeInt;
begin
  Visited.Size := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Visited[I] := True;
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aCycles.Add(TreePathFromTo(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

procedure TGSimpleGraph.SearchForFundamentalsCyclesLen(out aCycleLens: TIntVector);
var
  Stack: TIntStack;
  Visited: TBitVector;
  AdjEnums: TAdjEnumArray;
  Parents: TIntArray;
  EdgeSet: TIntPairSet;
  I, Curr, Next: SizeInt;
begin
  Visited.Size := VertexCount;
  AdjEnums := CreateAdjEnumArray;
  Parents := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Visited[I] := True;
        {%H-}Stack.Push(I);
        while Stack.TryPeek(Curr) do
          if AdjEnums[{%H-}Curr].MoveNext then
            begin
              Next := AdjEnums[Curr].Current;
              if not Visited[Next] then
                begin
                  Visited[Next] := True;
                  Parents[Next] := Curr;
                  Stack.Push(Next);
                end
              else
                if (Parents[Curr] <> Next) and EdgeSet.Add(Curr, Next) then
                  aCycleLens.Add(TreePathLen(Parents, Next, Curr));
            end
          else
            Stack.Pop;
      end;
end;

procedure TGSimpleGraph.FindFundamentalCyclesLen(out aCycleLens: TIntVector);
begin
  if IsTree then
    exit;
  SearchForFundamentalsCyclesLen(aCycleLens);
  if aCycleLens.Count <> CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  TIntVectorHelper.Sort(aCycleLens);
end;

function TGSimpleGraph.CreateDegreeArray: TIntArray;
var
  I: SizeInt;
begin
  Result := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    Result[I] := AdjLists[I]^.Count;
end;

function TGSimpleGraph.CreateComplementDegreeArray: TIntArray;
var
  I: SizeInt;
begin
  Result := CreateIntArray;
  for I := 0 to Pred(VertexCount) do
    Result[I] := VertexCount - AdjLists[I]^.Count;
end;

function TGSimpleGraph.SortVerticesByWidth(o: TSortOrder): TIntArray;
var
  I, J: SizeInt;
  List, Stack: TIntSet;
  m: TBoolMatrix;
begin
  Result := CreateDegreeArray;
  List.InitRange(VertexCount);
  if VertexCount > COMMON_BP_CUTOFF then
    while List.NonEmpty do
      begin
        I := List[0];
        for J in List do
          if Result[J] < Result[I] then
            I := J;
        {%H-}Stack.Push(I);
        List.Remove(I);
        for J in List do
          if AdjLists[I]^.Contains(J) then
            Dec(Result[J]);
      end
  else
    begin
      m := CreateBoolMatrix;
      while List.NonEmpty do
        begin
          I := List[0];
          for J in List do
            if Result[J] < Result[I] then
              I := J;
          {%H-}Stack.Push(I);
          List.Remove(I);
          for J in List do
            if m[I][J] then
              Dec(Result[J]);
        end;
    end;
  Result := Stack.ToArray;
  if o = soDesc then
    TIntHelper.Reverse(Result);
end;

function TGSimpleGraph.SortComplementByWidth: TIntArray;
var
  I, J: SizeInt;
  List, Stack: TIntSet;
  m: TBoolMatrix;
begin
  Result := CreateComplementDegreeArray;
  List.InitRange(VertexCount);
  if VertexCount > COMMON_BP_CUTOFF then
    while List.NonEmpty do
      begin
        I := List[0];
        for J in List do
          if Result[J] < Result[I] then
            I := J;
        {%H-}Stack.Push(I);
        List.Remove(I);
        for J in List do
          if not AdjLists[I]^.Contains(J) then
            Dec(Result[J]);
      end
  else
    begin
      m := CreateBoolMatrix;
      while List.NonEmpty do
        begin
          I := List[0];
          for J in List do
            if Result[J] < Result[I] then
              I := J;
          {%H-}Stack.Push(I);
          List.Remove(I);
          for J in List do
            if not m[I][J] then
              Dec(Result[J]);
        end
    end;
  Result := Stack.ToArray;
  TIntHelper.Reverse(Result);
end;

function TGSimpleGraph.SortVerticesByDegree(o: TSortOrder): TIntArray;
begin
  Result := CreateIntArrayRange;
  TSortByDegreeHelper.Sort(Result, @CmpByDegree, o);
end;

function TGSimpleGraph.CmpByDegree(constref L, R: SizeInt): SizeInt;
begin
  Result := SizeInt.Compare(AdjLists[L]^.Count, AdjLists[R]^.Count);
  if Result <> 0 then
    exit;
  if L < R then
    exit(-1);
  Result := 1;
end;

function TGSimpleGraph.CmpIntArrayLen(constref L, R: TIntArray): SizeInt;
begin
  if System.Length(L) > System.Length(R) then
    Result := 1
  else
    if System.Length(L) < System.Length(R) then
      Result := -1
    else
      Result := 0;
end;

class function TGSimpleGraph.MayBeEqual(L, R: TGSimpleGraph): Boolean;
var
  fcL, fcR: TIntVector;
  I: SizeInt;
begin
  if L = R then
    exit(True);
  if L.IsEmpty then
    exit(L.IsEmpty)
  else
    if R.IsEmpty then
      exit(False);
  if L.VertexCount <> R.VertexCount then
    exit(False);
  if L.EdgeCount <> R.EdgeCount then
    exit(False);
  L.FindFundamentalCyclesLen(fcL);
  R.FindFundamentalCyclesLen(fcR);
  if fcL.Count <> fcR.Count then
    exit(False);
  for I := 0 to Pred(fcL.Count) do
    if fcL[I] <> fcR[I] then
      exit(False);
  Result := True;
end;

constructor TGSimpleGraph.Create;
begin
  inherited;
  FConnectedValid := True;
end;

constructor TGSimpleGraph.Create(aCapacity: SizeInt);
begin
  inherited Create(aCapacity);
  FConnectedValid := True;
end;

procedure TGSimpleGraph.Clear;
begin
  inherited;
  FCompCount := 0;
  FConnected := False;
  FConnectedValid := True;
end;

procedure TGSimpleGraph.SaveToStream(aStream: TStream; aWriteVertex: TOnWriteVertex; aWriteData: TOnWriteData);
var
  Header: TStreamHeader;
  s, d: Integer;
  Edge: TEdge;
  gTitle, Descr: utf8string;
  wbs: TWriteBufStream;
begin
  if not Assigned(aWriteVertex) then
    raise EGraphError.Create(SEWriteCallbackMissed);
{$IFDEF CPU64}
  if VertexCount > System.High(Integer) then
    raise ELGraphError.CreateFmt(SEStreamSizeExceedFmt, [VertexCount]);
{$ENDIF CPU64}
  wbs := TWriteBufStream.Create(aStream);
  try
    //write header
    Header.Magic := GRAPH_MAGIC;
    Header.Version := GRAPH_HEADER_VERSION;
    gTitle := Title;
    Header.TitleLen := System.Length(gTitle);
    Descr := Description.Text;
    Header.DescriptionLen := System.Length(Descr);
    Header.VertexCount := VertexCount;
    Header.EdgeCount := EdgeCount;
    wbs.WriteBuffer(Header, SizeOf(Header));
    //write title
    if Header.TitleLen > 0 then
      wbs.WriteBuffer(Pointer(gTitle)^, Header.TitleLen);
    //write description
    if Header.DescriptionLen > 0 then
      wbs.WriteBuffer(Pointer(Descr)^, Header.DescriptionLen);
    //write Items, but does not save any info about connected
    //this should allow transfer data between directed/undirected graphs ???
    for s := 0 to Pred(Header.VertexCount) do
      aWriteVertex(wbs, FNodeList[s].Vertex);
    //write edges
    for Edge in DistinctEdges do
      begin
        s := Edge.Source;
        d := Edge.Destination;
        wbs.WriteBuffer(NtoLE(s), SizeOf(s));
        wbs.WriteBuffer(NtoLE(d), SizeOf(d));
        if Assigned(aWriteData) then
          aWriteData(wbs, Edge.Data);
      end;
  finally
    wbs.Free;
  end;
end;

procedure TGSimpleGraph.LoadFromStream(aStream: TStream; aReadVertex: TOnReadVertex; aReadData: TOnReadData);
var
  Header: TStreamHeader;
  s, d: Integer;
  I, Ind: SizeInt;
  Data: TEdgeData;
  Vertex: TVertex;
  gTitle, Descr: utf8string;
  rbs: TReadBufStream;
begin
  if not Assigned(aReadVertex) then
    raise EGraphError.Create(SEReadCallbackMissed);
  rbs := TReadBufStream.Create(aStream);
  try
    //read header
    rbs.ReadBuffer(Header, SizeOf(Header));
    if Header.Magic <> GRAPH_MAGIC then
      raise EGraphError.Create(SEUnknownGraphStreamFmt);
    if Header.Version > GRAPH_HEADER_VERSION then
      raise EGraphError.Create(SEUnsuppGraphFmtVersion);
    Clear;
    EnsureCapacity(Header.VertexCount);
    //read title
    if Header.TitleLen > 0 then
      begin
        System.SetLength(gTitle, Header.TitleLen);
        rbs.ReadBuffer(Pointer(gTitle)^, Header.TitleLen);
        FTitle := gTitle;
      end;
    //read description
    if Header.DescriptionLen > 0 then
      begin
        System.SetLength(Descr, Header.DescriptionLen);
        rbs.ReadBuffer(Pointer(Descr)^, Header.DescriptionLen);
        Description.Text := Descr;
      end;
    //read Items
    for I := 0 to Pred(Header.VertexCount) do
      begin
        aReadVertex(rbs, Vertex);
        if not AddVertex(Vertex, Ind) then
          raise EGraphError.Create(SEGraphStreamCorrupt);
        if Ind <> I then
          raise EGraphError.Create(SEGraphStreamReadIntern);
      end;
    //read edges
    Data := DefaultEdgeData;
    for I := 0 to Pred(Header.EdgeCount) do
      begin
        rbs.ReadBuffer(s, SizeOf(s));
        rbs.ReadBuffer(d, SizeOf(d));
        if Assigned(aReadData) then
          aReadData(rbs, Data);
        AddEdgeI(LEToN(s), LEToN(d), Data);
      end;
  finally
    rbs.Free;
  end;
end;

procedure TGSimpleGraph.SaveToFile(const aFileName: string; aWriteVertex: TOnWriteVertex;
  aWriteData: TOnWriteData);
var
  fs: TStream;
begin
  fs := TFileStream.Create(aFileName, fmCreate);
  try
    SaveToStream(fs, aWriteVertex, aWriteData);
  finally
    fs.Free;
  end;
end;

procedure TGSimpleGraph.LoadFromFile(const aFileName: string; aReadVertex: TOnReadVertex; aReadData: TOnReadData);
var
  fs: TStream;
begin
  fs := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(fs, aReadVertex, aReadData);
  finally
    fs.Free;
  end;
end;

function TGSimpleGraph.Clone: TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignGraph(Self);
end;

function TGSimpleGraph.SeparateGraph(constref aVertex: TVertex): TGSimpleGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparateGraphI(aIndex: SizeInt): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self)
end;

function TGSimpleGraph.SubgraphFromVertexList(constref aList: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGSimpleGraph.SubgraphFromTree(constref aTree: TIntArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGSimpleGraph.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGSimpleGraph;
begin
  Result := TGSimpleGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGSimpleGraph.CreateLineGraph: TLineGraph;
var
  I, J: SizeInt;
  vI, vJ: TIntPair;
  e: TEdge;
begin
  Result := TLineGraph.Create(EdgeCount);
  for e in DistinctEdges do
    Result.AddVertex(TIntPair.Create(e.Source, e.Destination));
  for I := 0 to Result.VertexCount - 2 do
    begin
      vI := Result[I];
      for J := Succ(I) to Pred(Result.VertexCount) do
        begin
          vJ := Result[J];
          if (vI.Left = vJ.Left) or (vI.Left = vJ.Right) then
            Result.AddEdgeI(I, J, TIntValue.Create(vI.Left))
          else
            if (vI.Right = vJ.Left) or (vI.Right = vJ.Right) then
               Result.AddEdgeI(I, J, TIntValue.Create(vI.Right))
        end;
    end;
end;

function TGSimpleGraph.AddVertex(constref aVertex: TVertex; out aIndex: SizeInt): Boolean;
begin
  Result := not FindOrAdd(aVertex, aIndex);
  if not Result then
    exit;
  if ConnectedValid then
    begin
      FNodeList[aIndex].Tag := aIndex;
      Inc(FCompCount);
      FConnected := FCompCount = 1;
    end
  else
    FNodeList[aIndex].Tag := FCompCount;
end;

function TGSimpleGraph.AddVertex(constref aVertex: TVertex): Boolean;
var
  Dummy: SizeInt;
begin
  Result := AddVertex(aVertex, Dummy);
end;

procedure TGSimpleGraph.RemoveVertex(constref aVertex: TVertex);
begin
  RemoveVertexI(IndexOf(aVertex));
end;

procedure TGSimpleGraph.RemoveVertexI(aIndex: SizeInt);
begin
  CheckIndexRange(aIndex);
  DoRemoveVertex(aIndex);
end;

function TGSimpleGraph.AddEdge(constref aSrc, aDst: TVertex; aData: TEdgeData): Boolean;
var
  SrcIdx, DstIdx: SizeInt;
begin
  AddVertex(aSrc, SrcIdx);
  AddVertex(aDst, DstIdx);
  Result := DoAddEdge(SrcIdx, DstIdx, aData);
end;

function TGSimpleGraph.AddEdge(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := AddEdge(aSrc, aDst, DefaultEdgeData);
end;

function TGSimpleGraph.AddEdgeI(aSrc, aDst: SizeInt; aData: TEdgeData): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := DoAddEdge(aSrc, aDst, aData);
end;

function TGSimpleGraph.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := AddEdgeI(aSrc, aDst, DefaultEdgeData);
end;

function TGSimpleGraph.RemoveEdge(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := RemoveEdgeI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.RemoveEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := DoRemoveEdge(aSrc, aDst);
end;

function TGSimpleGraph.Degree(constref aVertex: TVertex): SizeInt;
begin
  Result := DegreeI(IndexOf(aVertex));
end;

function TGSimpleGraph.DegreeI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := FNodeList[aIndex].AdjList.Count;
end;

function TGSimpleGraph.Isolated(constref aVertex: TVertex): Boolean;
begin
  Result := Degree(aVertex) = 0;
end;

function TGSimpleGraph.IsolatedI(aIndex: SizeInt): Boolean;
begin
  Result := DegreeI(aIndex) = 0;
end;

function TGSimpleGraph.DistinctEdges: TDistinctEdges;
begin
  Result.FGraph := Self;
end;

function TGSimpleGraph.Eccentricity(constref aVertex: TVertex): SizeInt;
begin
  Result := EccentricityI(IndexOf(aVertex));
end;

function TGSimpleGraph.EccentricityI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  Result := GetEccentricity(aIndex);
end;

function TGSimpleGraph.LocalClustering(constref aVertex: TVertex): ValReal;
begin
  Result := LocalClusteringI(IndexOf(aVertex));
end;

function TGSimpleGraph.LocalClusteringI(aIndex: SizeInt): Double;
var
  I, J, Counter, d: SizeInt;
begin
  CheckIndexRange(aIndex);
  d := DegreeI(aIndex);
  if d <= 1 then
    exit(0.0);
  Counter := 0;
  for I in AdjVerticesI(aIndex) do
    for J in AdjVerticesI(aIndex) do
      Counter += Ord((I <> J) and FNodeList[I].AdjList.Contains(J));
  Result := Double(Counter) / (Double(d) * Double(Pred(d)));
end;

function TGSimpleGraph.EnsureConnected(aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := 0;
  if VertexCount < 2 then
    exit;
  if SeparateCount < 2 then
    exit;
  Result := MakeConnected(aOnAddEdge);
end;

function TGSimpleGraph.PathExists(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := PathExistsI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGSimpleGraph.PathExistsI(aSrc, aDst: SizeInt): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aSrc = aDst then
    exit(True);
  if SeparateCount > 1 then
    Result := SeparateTag(aSrc) = SeparateTag(aDst)
  else
    Result := True;
end;

function TGSimpleGraph.SeparateIndexOf(constref aVertex: TVertex): SizeInt;
begin
   Result := SeparateIndexI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparateIndexI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  if not ConnectedValid then
    ValidateConnected;
  Result := SeparateTag(aIndex);
end;

function TGSimpleGraph.SeparatePop(constref aVertex: TVertex): SizeInt;
begin
  Result := SeparatePopI(IndexOf(aVertex));
end;

function TGSimpleGraph.SeparatePopI(aIndex: SizeInt): SizeInt;
begin
  CheckIndexRange(aIndex);
  if SeparateCount > 1 then
    Result := CountPop(SeparateTag(aIndex))
  else
    Result := VertexCount;
end;

function TGSimpleGraph.IsTree: Boolean;
begin
  Result := (EdgeCount = Pred(VertexCount)) and Connected;
end;

function TGSimpleGraph.CyclomaticNumber: SizeInt;
begin
  Result := EdgeCount - VertexCount + SeparateCount;
end;

function TGSimpleGraph.IsRegular: Boolean;
var
  I, d: SizeInt;
begin
  if NonEmpty then
    begin
      d := DegreeI(0);
      for I := 1 to Pred(VertexCount) do
        if DegreeI(I) <> d then
          exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.ContainsCycle(constref aRoot: TVertex; out aCycle: TIntArray): Boolean;
begin
  Result := ContainsCycleI(IndexOf(aRoot), aCycle);
end;

function TGSimpleGraph.ContainsCycleI(aRoot: SizeInt; out aCycle: TIntArray): Boolean;
begin
  CheckIndexRange(aRoot);
  if VertexCount < 3 then
    exit(False);
  if ConnectedValid and IsTree then
    exit(False);
  Result := CycleExists(aRoot, aCycle);
end;

function TGSimpleGraph.ContainsEulerianCircuit: Boolean;
var
  I, d, cd: SizeInt;
begin
  if VertexCount < 3 then
    exit(False);
  d := 0;
  for I := 0 to Pred(VertexCount) do
    begin
      cd := DegreeI(I);
      if Odd(cd) then
        exit(False);
      d += cd;
    end;
  Result := d > 0;
end;

function TGSimpleGraph.FindEulerianCircuit(out aCircuit: TIntVector): Boolean;
var
  g: TSkeleton;
  Stack: TIntStack;
  s, d: SizeInt;
begin
  if not ContainsEulerianCircuit then
    exit(False);
  g := CreateSkeleton;
  s := 0;
  while g.Degree[s] = 0 do
    Inc(s);
  aCircuit.Add(s);
  repeat
    while g[s]^.FindFirst(d) do
      begin
        {%H-}Stack.Push(s);
        g.RemoveEdge(s, d);
        s := d;
      end;
    if not Stack.TryPop(s) then
      break;
    aCircuit.Add(s);
  until False;
  Result := aCircuit.Count > 0;
  if Result then
    TIntVectorHelper.Reverse(aCircuit);
end;

function TGSimpleGraph.FindFundamentalCycles(out aCycles: TIntArrayVector): Boolean;
begin
  if IsTree then
    exit(False);
  SearchForFundamentalsCycles(aCycles);
  if aCycles.Count <> CyclomaticNumber then
    raise EGraphError.Create(SEInternalDataInconsist);
  TIntArrayVectorHelper.Sort(aCycles, @CmpIntArrayLen);
  Result := True;
end;

function TGSimpleGraph.ContainsCutPoint(constref aRoot: TVertex): Boolean;
begin
  Result := ContainsCutPointI(IndexOf(aRoot));
end;

function TGSimpleGraph.ContainsCutPointI(aRoot: SizeInt): Boolean;
begin
  CheckIndexRange(aRoot);
  if VertexCount < 3 then
    exit(False);
  Result := CutPointExists(aRoot);
end;

function TGSimpleGraph.FindCutPoints(constref aRoot: TVertex): TIntArray;
begin
  Result := FindCutPointsI(IndexOf(aRoot));
end;

function TGSimpleGraph.FindCutPointsI(aRoot: SizeInt): TIntArray;
var
  v: TIntVector;
begin
  CheckIndexRange(aRoot);
  if VertexCount > 2 then
    begin
      SearchForCutPoints(aRoot, v{%H-});
      Result := v.ToArray;
    end
  else
    Result := nil;
end;

function TGSimpleGraph.RemoveCutPoints(constref aRoot: TVertex; aOnAddEdge: TOnAddEdge): SizeInt;
begin
  Result := RemoveCutPointsI(IndexOf(aRoot), aOnAddEdge);
end;

function TGSimpleGraph.RemoveCutPointsI(aRoot: SizeInt; aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := 0;
  if VertexCount < 3 then
    exit;
  SearchForBiconnect(aRoot, NewEdges{%H-});
  d := DefaultEdgeData;
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(FNodeList[e.Source].Vertex, FNodeList[e.Destination].Vertex, @d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.ContainsBridge: Boolean;
begin
  if VertexCount > 1 then
    Result := BridgeExists
  else
    Result := False;
end;

function TGSimpleGraph.FindBridges: TIntEdgeArray;
var
  v: TIntEdgeVector;
begin
  if VertexCount > 1 then
    SearchForBridges(v{%H-});
  Result := v.ToArray;
end;

function TGSimpleGraph.FindBicomponents(constref aRoot: TVertex; out aComponents: TEdgeArrayVector): SizeInt;
begin
  Result := FindBicomponentsI(IndexOf(aRoot), aComponents);
end;

function TGSimpleGraph.FindBicomponentsI(aRoot: SizeInt; out aComponents: TEdgeArrayVector): SizeInt;
begin
  Result := 0;
  CheckIndexRange(aRoot);
  if VertexCount > 2 then
    begin
      SearchForBicomponent(aRoot, aComponents{%H-});
      Result := aComponents.Count;
    end
  else
    if (VertexCount = 2) and ContainsEdgeI(0, 1) then
      begin
        aComponents.Add([TIntEdge.Create(0, 1)]);
        Result := 1;
      end;
end;

function TGSimpleGraph.IsBiconnected: Boolean;
begin
  if Connected then
    Result := not ContainsCutPointI
  else
    Result := False;
end;

function TGSimpleGraph.EnsureBiconnected(aOnAddEdge: TOnAddEdge): SizeInt;
var
  NewEdges: TIntEdgeVector;
  e: TIntEdge;
  d: TEdgeData;
begin
  Result := EnsureConnected(aOnAddEdge);
  if VertexCount < 3 then
    exit;
  SearchForBiconnect(0, NewEdges{%H-});
  d := DefaultEdgeData;
  for e in NewEdges do
    begin
      if Assigned(aOnAddEdge) then
        aOnAddEdge(Items[e.Source], Items[e.Destination], @d);
      Result += Ord(AddEdgeI(e.Source, e.Destination, d));
    end;
end;

function TGSimpleGraph.MinCut: SizeInt;
var
  Helper: TNIMinCut;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    exit(1);
  Result := Helper.GetMinCut(Self);
end;

function TGSimpleGraph.MinCut(out aCut: TCut): SizeInt;
var
  Helper: TNIMinCut;
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
begin
  if not Connected or (VertexCount < 2) then
    exit(0);
  if VertexCount = 2 then
    begin
      aCut.A := [0];
      aCut.B := [1];
      exit(1);
    end;
  Result := Helper.GetMinCut(Self, Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
end;

function TGSimpleGraph.CrossMinCut: TIntEdgeArray;
var
  Helper: TNIMinCut;
  Cut: TIntSet;
  Left, Right: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
begin
  if not Connected or (VertexCount < 2) then
    exit([]);
  if VertexCount = 2 then
    exit([TIntEdge.Create(0, 1)]);
  System.SetLength(Result, Helper.GetMinCut(Self, Cut));
  if Cut.Count <= VertexCount shr 1 then
    begin
      Left.Size := VertexCount;
      Right.InitRange(VertexCount);
      for I in Cut do
        begin
          Left[I] := True;
          Right[I] := False;
        end;
    end
  else
    begin
      Right.Size := VertexCount;
      Left.InitRange(VertexCount);
      for I in Cut do
        begin
          Right[I] := True;
          Left[I] := False;
        end;
    end;
  J := 0;
  for I in Left do
    for p in AdjLists[I]^ do
      if Right[p^.Destination] then
        begin
          if I < p^.Destination then
            Result[J] := TIntEdge.Create(I, p^.Destination)
          else
            Result[J] := TIntEdge.Create(p^.Destination, I);
          Inc(J);
        end;
end;

function TGSimpleGraph.ComplementMatrix: TAdjacencyMatrix;
var
  m: TSquareBitMatrix;
  s, d: SizeInt;
begin
  if IsEmpty then
    exit(Default(TAdjacencyMatrix));
  m := TSquareBitMatrix.Create(VertexCount);
  for s := 0 to Pred(VertexCount) do
    for d := 0 to Pred(VertexCount) do
      if (s <> d) and not FNodeList[s].AdjList.Contains(d) then
        m[s, d] := True;
  Result := TAdjacencyMatrix.Create(m);
end;

function TGSimpleGraph.DfsSpanningTree(constref aRoot: TVertex): TIntArray;
begin
  Result := DfsSpanningTreeI(IndexOf(aRoot));
end;

function TGSimpleGraph.DfsSpanningTreeI(aRoot: SizeInt): TIntArray;
var
  Visited: TBitVector;
  Stack: TIntStack;
  AdjEnums: TAdjEnumArray;
  Next: SizeInt;
begin
  CheckIndexRange(aRoot);
  Visited.Size := VertexCount;
  Result := CreateIntArray;
  AdjEnums := CreateAdjEnumArray;
  Visited[aRoot] := True;
  {%H-}Stack.Push(aRoot);
  while Stack.TryPeek(aRoot) do
    if AdjEnums[aRoot].MoveNext then
      begin
        Next := AdjEnums[aRoot].Current;
        if not Visited[Next] then
          begin
            Visited[Next] := True;
            Result[Next] := aRoot;
            Stack.Push(Next);
          end;
      end
    else
      Stack.Pop;
end;

function TGSimpleGraph.BfsSpanningTree(constref aRoot: TVertex): TIntArray;
begin
  Result := BfsSpanningTreeI(IndexOf(aRoot));
end;

function TGSimpleGraph.BfsSpanningTreeI(aRoot: SizeInt): TIntArray;
var
  Visited: TBitVector;
  Queue: TIntQueue;
  Next: SizeInt;
begin
  CheckIndexRange(aRoot);
  Visited.Size := VertexCount;
  Result := CreateIntArray;
  Visited[aRoot] := True;
  repeat
    for Next in AdjVerticesI(aRoot) do
      if not Visited[Next] then
        begin
          Visited[Next] := True;
          Result[Next] := aRoot;
          Queue.Enqueue(Next);
        end;
  until not Queue{%H-}.TryDequeue(aRoot);
end;

function TGSimpleGraph.FindMaxBipartiteMatchingHK(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: THKMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.GetMaxMatch(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.MaxBipartiteMatchingHK(constref aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: THKMatch;
begin
  Result := Helper.GetMaxMatch(Self, aWhites, aGrays);
end;

function TGSimpleGraph.FindMaxBipartiteMatchingBfs(out aMatch: TIntEdgeArray): Boolean;
var
  Helper: TBfsMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.GetMaxMatch(Self, w, g);
  Result := True;
end;

function TGSimpleGraph.MaxBipartiteMatchingBfs(constref aWhites, aGrays: TIntArray): TIntEdgeArray;
var
  Helper: TBfsMatch;
begin
  Result := Helper.GetMaxMatch(Self, aWhites, aGrays);
end;

function TGSimpleGraph.IsMaxBipartiteMatching(constref aMatch: TIntEdgeArray): Boolean;
var
  w, g: TIntArray;
  WhiteFree, GrayFree,
  WhiteCover, GrayCover: TIntHashSet;
  e: TIntEdge;
  I, J: SizeInt;
begin
  if System.Length(aMatch) = 0 then
    exit(False);
  if not IsBipartite(w, g) then
    exit(False);
  WhiteFree.AddAll(w);
  GrayFree.AddAll(g);
  w := nil;
  g := nil;
  for e in aMatch do
    begin
      if SizeUInt(e.Source) >= SizeUInt(VertexCount) then
        exit(False);
      if SizeUInt(e.Destination) >= SizeUInt(VertexCount) then
        exit(False);
      if e.Source = e.Destination then
        exit(False);
      if not AdjLists[e.Source]^.Contains(e.Destination) then
        exit(False);
      if WhiteFree.Remove(e.Source) then
        begin
          if not GrayFree.Remove(e.Destination) then  //contains adjacent edges -> not matching
            exit(False);
          WhiteCover.Add(e.Source);
          GrayCover.Add(e.Destination)
        end
      else
        begin
          if not WhiteFree.Remove(e.Destination)then //contains adjacent edges -> not matching
            exit(False);
          if not GrayFree.Remove(e.Source) then      //contains adjacent edges -> not matching
            exit(False);
          WhiteCover.Add(e.Destination);
          GrayCover.Add(e.Source);
        end;
    end;
  for I in WhiteFree do
    for J in AdjVerticesI(I) do
      if GrayFree.Contains(J) then  // is not maximal
        exit(False);
  Result := True;
end;

function TGSimpleGraph.ApproxMaxMatching: TIntEdgeArray;
begin
  if VertexCount < 2 then
    exit([]);
  if (VertexCount = 2) and Connected then
    exit([TIntEdge.Create(0, 1)]);
  Result := GetApproxMatching2;
end;

function TGSimpleGraph.MaxMatchingEd: TIntEdgeArray;
var
  Helper: TEdMatch;
begin
  if VertexCount < 2 then
    exit([]);
  if not FindMaxBipartiteMatchingHK(Result) then
    Result := Helper.GetMaxMatch(Self);
end;

function TGSimpleGraph.MaxMatchingPC: TIntEdgeArray;
var
  Helper: TPapeMatch;
begin
  if VertexCount < 2 then
    exit([]);
  if not FindMaxBipartiteMatchingBfs(Result) then
    Result := Helper.GetMaxMatch(Self);
end;

function TGSimpleGraph.MaxMatchingMV: TIntEdgeArray;
begin
  if VertexCount < 2 then
    exit([]);
  if not FindMaxBipartiteMatchingHK(Result) then
    Result := GetMvMatching;
end;

procedure TGSimpleGraph.ListIndependentSets(aOnFindSet: TOnFindSet);
begin
  if IsEmpty then
    exit;
  if aOnFindSet = nil then
    raise EGraphError.Create(SECallbackMissed);
  if VertexCount > TBits256.BITNESS then
    ListIsBP(aOnFindSet)
  else
    ListIsBP256(aOnFindSet)
end;

function TGSimpleGraph.MaxIndependentSet(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
var
  w, g: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount < 2 then
    exit([0]);
  if IsBipartite(w, g) then
    Result := GetMaxIsBipartite(w, g)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMaxIsBP(aTimeOut, aExactSolution)
    else
      Result := GetMaxIsBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.ApproxMaxIndependentSet: TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if VertexCount = 1 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetApproxMaxIS
  else
    Result := GetApproxMaxIsBP;
end;

function TGSimpleGraph.IsMaxIndependentSet(constref aVertexSet: TIntArray): Boolean;
var
  TestIS, Remain: TBoolVector;
  I, J: SizeInt;
  AdjFound: Boolean;
begin
  if System.Length(aVertexSet) = 0 then
    exit(False);
  TestIS.Size := VertexCount;
  for I in aVertexSet do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestIS[I] then  //contains duplicates -> is not set
        exit(False);
      TestIS[I] := True;
    end;
  for I in aVertexSet do
    for J in aVertexSet do
      if (I <> J) and AdjacentI(I, J) then //contains adjacent vertices -> is not independent
        exit(False);
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestIS);
  Finalize(TestIS);
  for I in Remain do
    begin
      AdjFound := False;
      for J in aVertexSet do
        if AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then //I can be added to aVertexSet -> aVertexSet is not maximal
        exit(False);
    end;
  Result := True;
end;

function TGSimpleGraph.MinDominatingSet(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
begin
  if not Connected then
    raise EGraphError.Create(SEMethodNotApplicable);
  if VertexCount < 3 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetMds(aTimeOut, aExactSolution)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMdsBP(aTimeOut, aExactSolution)
    else
      Result := GetMdsBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.ApproxMinDominatingSet: TIntArray;
begin
  if not Connected then
    raise EGraphError.Create(SEMethodNotApplicable);
  if VertexCount < 3 then
    exit([0]);
  if VertexCount > COMMON_BP_CUTOFF then
    Result := GetApproxMinIS
  else
    Result := GetApproxMinIsBP;
end;

function TGSimpleGraph.IsMinDominatingSet(constref aVertexSet: TIntArray): Boolean;
var
  TestMds, Remain: TBoolVector;
  I, J, K: SizeInt;
  AdjFound: Boolean;
begin
  if not Connected then
    exit(False);
  if System.Length(aVertexSet) = 0 then
    exit(False);
  TestMds.Size := VertexCount;
  for I in aVertexSet do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestMds[I] then   //contains duplicates -> is not set
        exit(False);
      TestMds[I] := True;
    end;
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestMds);
  Finalize(TestMds);
  for I in Remain do
    begin
      AdjFound := False;
      for J in aVertexSet do
        if AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if not AdjFound then //is not dominating set
        exit(False);
    end;

  for I in aVertexSet do
    begin
      AdjFound := False;
      for J in aVertexSet do
        if (I <> J) and AdjacentI(I, J) then
          begin
            AdjFound := True;
            break;
          end;
      if AdjFound then //test aVertexSet without I
        begin
          for K in Remain do
            begin
              AdjFound := False;
              for J in aVertexSet do
                if (K <> J) and (J <> I) and AdjacentI(K, J) then
                  begin
                    AdjFound := True;
                    break;
                  end;
              if not AdjFound then //exists vertex nonadjacent with aVertexSet without I
                break;
            end;
          if AdjFound then  //is not minimal
            exit(False);
        end;
    end;
  Result := True;
end;

procedure TGSimpleGraph.ListMaxCliques(aOnFindClique: TOnFindSet);
begin
  if IsEmpty then
    exit;
  if aOnFindClique = nil then
    raise EGraphError.Create(SECallbackMissed);
  if (VertexCount > LISTCLIQUES_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    ListCliques(aOnFindClique)
  else
    if VertexCount > TBits256.BITNESS then
      ListCliquesBP(aOnFindClique)
    else
      ListCliquesBP256(aOnFindClique);
end;

function TGSimpleGraph.MaxClique(out aExactSolution: Boolean; aTimeOut: Integer): TIntArray;
begin
  if IsEmpty then
    exit(nil);
  if (VertexCount >= COMMON_BP_CUTOFF) or (Density <= MAXCLIQUE_BP_DENSITY_CUTOFF) then
    Result := GetMaxClique(aTimeOut, aExactSolution)
  else
    if VertexCount > TBits256.BITNESS then
      Result := GetMaxCliqueBP(aTimeOut, aExactSolution)
    else
      Result := GetMaxCliqueBP256(aTimeOut, aExactSolution);
end;

function TGSimpleGraph.ApproxMaxClique: TIntArray;
var
  Cand, Stack, Q: TIntSet;
  I, J: SizeInt;
begin
  if IsEmpty then
    exit(nil);
  Cand.AssignArray(SortVerticesByWidth(soAsc));
  while Cand.NonEmpty do
    begin
      I := Cand.Pop;
      {%H-}Stack.Push(I);
      {%H-}Q.MakeEmpty;
      for J in Cand do
        if AdjLists[I]^.Contains(J) then
          Q.Push(J);
      Cand.Assign(Q);
    end;
  Result := Stack.ToArray;
end;

function TGSimpleGraph.IsMaxClique(constref aClique: TIntArray): Boolean;
var
  TestClique, Remain: TBoolVector;
  I, J: SizeInt;
  AdjFound: Boolean;
begin
  if System.Length(aClique) = 0 then
    exit(False);
  TestClique.Size := VertexCount;
  for I in aClique do
    begin
      if SizeUInt(I) >= SizeUInt(VertexCount) then //contains garbage
        exit(False);
      if TestClique[I] then //contains duplicates -> is not set
        exit(False);
      TestClique[I] := True;
    end;
  for I in aClique do
    for J in aClique do
      if (I <> J) and not AdjacentI(I, J) then //contains nonadjacent vertices -> is not clique
        exit(False);
  Remain.InitRange(VertexCount);
  Remain.Subtract(TestClique);
  Finalize(TestClique);
  for I in Remain do
    begin
      AdjFound := True;
      for J in aClique do
        if not AdjacentI(I, J) then
          begin
            AdjFound := False;
            break;
          end;
      if AdjFound then // I can be added to clique -> clique is not maximal
        exit(False);
    end;
  Result := True;
end;

{ TGChart }

function TGChart.AddEdge(constref aSrc, aDst: TVertex): Boolean;
begin
  Result := inherited AddEdge(aSrc, aDst);
end;

function TGChart.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := inherited AddEdgeI(aSrc, aDst);
end;

function TGChart.EnsureConnected: SizeInt;
begin
  Result := inherited EnsureConnected(nil);
end;

function TGChart.RemoveCutPoints(constref aRoot: TVertex): SizeInt;
begin
  Result := inherited RemoveCutPoints(aRoot, nil);
end;

function TGChart.RemoveCutPointsI(aRoot: SizeInt): SizeInt;
begin
  Result := inherited RemoveCutPointsI(aRoot, nil);
end;

function TGChart.EnsureBiconnected: SizeInt;
begin
  Result := inherited EnsureBiconnected(nil);
end;

procedure TGChart.SaveToStream(aStream: TStream; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToStream(aStream, aOnWriteVertex, nil);
end;

procedure TGChart.LoadFromStream(aStream: TStream; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromStream(aStream, aOnReadVertex, nil);
end;

procedure TGChart.SaveToFile(const aFileName: string; aOnWriteVertex: TOnWriteVertex);
begin
  inherited SaveToFile(aFileName, aOnWriteVertex, nil);
end;

procedure TGChart.LoadFromFile(const aFileName: string; aOnReadVertex: TOnReadVertex);
begin
  inherited LoadFromFile(aFileName, aOnReadVertex, nil);
end;

function TGChart.SeparateGraph(constref aVertex: TVertex): TGChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGChart.SeparateGraphI(aIndex: SizeInt): TGChart;
begin
  Result := TGChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGChart.SubgraphFromVertexList(constref aList: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGChart.SubgraphFromTree(constref aTree: TIntArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TGChart.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGChart;
begin
  Result := TGChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGChart.Clone: TGChart;
begin
  Result := TGChart.Create;
  Result.AssignGraph(Self);
end;

{ TIntChart }

procedure TIntChart.WriteVertex(aStream: TStream; constref aValue: Integer);
begin
  aStream.WriteBuffer(NtoLE(aValue), SizeOf(aValue));
end;

procedure TIntChart.ReadVertex(aStream: TStream; out aValue: Integer);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue := LEtoN(aValue);
end;

procedure TIntChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TIntChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TIntChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TIntChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

procedure TIntChart.LoadFromDIMACSAsciiFile(const aFileName: string);
type
  TReaderRef = specialize TGAutoRef<TTextFileReader>;
var
  ReaderRef: TReaderRef;
  Reader: TTextFileReader;
  Line, ParseLine, Elem: string;
  I: SizeInt;
  CurrEdge: array[0..1] of SizeInt;
  Symb: AnsiChar;
begin
  Reader := ReaderRef;
  if not Reader.Open(aFileName) then
    raise EGraphError.CreateFmt(SEUnableOpenFileFmt, [aFileName]);
  Clear;
  for Line in Reader do
    begin
      ParseLine := Trim(Line);
      Symb := LowerCase(ParseLine)[1];
      case Symb of
        'c':
          begin
            Description.Add(System.Copy(ParseLine, 3, System.Length(ParseLine)));
            continue;
          end;
        'e':
          begin
            I := 0;
            for Elem in Line.SplitSB([' ']) do
              begin
                if LowerCase(Elem) = Symb then
                  continue;
                CurrEdge[I] := StrToInt(Elem);
                if I = 1 then
                  break;
                Inc(I);
              end;
            if I = 0 then
              begin
                Clear;
                raise EGraphError.Create(SEUnexpectEol);
              end;
            AddEdge(CurrEdge[0], CurrEdge[1]);
          end;
      end;
    end;
end;

function TIntChart.SeparateGraph(aVertex: Integer): TIntChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TIntChart.SeparateGraphI(aIndex: SizeInt): TIntChart;
begin
  Result := TIntChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TIntChart.SubgraphFromVertexList(constref aList: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TIntChart.SubgraphFromTree(constref aTree: TIntArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TIntChart.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TIntChart.Clone: TIntChart;
begin
  Result := TIntChart.Create;
  Result.AssignGraph(Self);
end;

{ TStrChart }

procedure TStrChart.WriteVertex(aStream: TStream; constref aValue: string);
var
  Len: SizeInt;
begin
  Len := System.Length(aValue);
  if Len > High(SmallInt) then
    raise EGraphError.CreateFmt(SEStrLenExceedFmt, [Len]);
  aStream.WriteBuffer(Len, 2);
  if Len > 0 then
    aStream.WriteBuffer(aValue[1], Len);
end;

procedure TStrChart.ReadVertex(aStream: TStream; out aValue: string);
var
  Len: SmallInt;
begin
  aStream.ReadBuffer(Len{%H-}, SizeOf(Len));
  System.SetLength(aValue, Len);
  if Len > 0 then
    aStream.ReadBuffer(aValue[1], Len);
end;

procedure TStrChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WriteVertex);
end;

procedure TStrChart.LoadFromStream(aStream: TStream);
begin
  inherited LoadFromStream(aStream, @ReadVertex);
end;

procedure TStrChart.SaveToFile(const aFileName: string);
begin
  inherited SaveToFile(aFileName, @WriteVertex);
end;

procedure TStrChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadVertex);
end;

function TStrChart.SeparateGraph(const aVertex: string): TStrChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TStrChart.SeparateGraphI(aIndex: SizeInt): TStrChart;
begin
  Result := TStrChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TStrChart.SubgraphFromVertexList(constref aList: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TStrChart.SubgraphFromTree(constref aTree: TIntArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TStrChart.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TStrChart.Clone: TStrChart;
begin
  Result := TStrChart.Create;
  Result.AssignGraph(Self);
end;

{ TGWeightedGraph.TKuhnMatch }

procedure TGWeightedGraph.TKuhnMatch.Match(aNode, aMate: SizeInt);
begin
  FMates[aNode] := aMate;
  FMates[aMate] := aNode;
end;

procedure TGWeightedGraph.TKuhnMatch.ClearParents;
begin
  System.FillChar(Pointer(FParents)^, System.Length(FParents) * SizeOf(SizeUint), $ff);
end;

procedure TGWeightedGraph.TKuhnMatch.Init(aGraph: TGWeightedGraph; constref w, g: TIntArray);
var
  I: SizeInt;
  p: PAdjItem;
  ew: TWeight;
begin
  FGraph := aGraph;
  FMatchCount := 0;
  FWhites.Size := aGraph.VertexCount;
  if System.Length(w) <= System.Length(g) then
    for I in w do
      FWhites[I] := True
  else
    for I in g do
      FWhites[I] := True;

  FPots := TPathHelper.CreateWeightArrayZ(aGraph.VertexCount);
  for I in FWhites do
    begin
      ew := InfWeight;
      for p in aGraph.AdjLists[I]^ do
        if p^.Data.Weight < ew then
          ew := p^.Data.Weight;
      FPots[I] := ew;
    end;

  FMates := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FVisited.Size := aGraph.VertexCount;
end;

procedure TGWeightedGraph.TKuhnMatch.InitMax(aGraph: TGWeightedGraph; constref w, g: TIntArray);
var
  I: SizeInt;
  p: PAdjItem;
  ew: TWeight;
begin
  FGraph := aGraph;
  FMatchCount := 0;
  FWhites.Size := aGraph.VertexCount;
  if System.Length(w) <= System.Length(g) then
    for I in w do
      FWhites[I] := True
  else
    for I in g do
      FWhites[I] := True;

  FPots := TPathHelper.CreateWeightArrayZ(aGraph.VertexCount);
  for I in FWhites do
    begin
      ew := InfWeight;
      for p in aGraph.AdjLists[I]^ do
        if p^.Data.Weight > ew then
          ew := p^.Data.Weight;
      FPots[I] := ew;
    end;

  FMates := aGraph.CreateIntArray;
  FParents := aGraph.CreateIntArray;
  FQueue := aGraph.CreateIntArray;
  FVisited.Size := aGraph.VertexCount;
end;

function TGWeightedGraph.TKuhnMatch.FindAugmentPath(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
var
  Curr, Next: SizeInt;
  p: PAdjItem;
  Cost: TWeight;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      FVisited[Curr] := True;
      if FWhites[Curr] then
        begin
          for p in FGraph.AdjLists[Curr]^ do
            begin
              Next := p^.Destination;
              if (FMates[Curr] = Next) or (FParents[Next] <> NULL_INDEX) then
                continue;
              Cost := p^.Data.Weight + FPots[Next] - FPots[Curr];
              if Cost <= ZeroWeight then
                begin
                  if FMates[Next] = NULL_INDEX then
                    begin
                      FParents[Next] := Curr;
                      exit(Next);
                    end
                  else
                    if not FVisited[Next] then
                      begin
                        FParents[Next] := Curr;
                        FQueue[qTail] := Next;
                        Inc(qTail);
                      end;
                end
              else
                if Cost < aDelta then
                  aDelta := Cost;
            end;
        end
      else
        begin
          Next := FMates[Curr];
          FParents[Next] := Curr;
          FQueue[qTail] := Next;
          Inc(qTail);
        end;
    end;
  Result := NULL_INDEX;
end;

function TGWeightedGraph.TKuhnMatch.FindAugmentPathMax(aRoot: SizeInt; var aDelta: TWeight): SizeInt;
var
  Curr, Next: SizeInt;
  p: PAdjItem;
  Cost: TWeight;
  qHead: SizeInt = 0;
  qTail: SizeInt = 0;
begin
  FQueue[qTail] := aRoot;
  Inc(qTail);
  while qHead < qTail do
    begin
      Curr := FQueue[qHead];
      Inc(qHead);
      FVisited[Curr] := True;
      if FWhites[Curr] then
        begin
          for p in FGraph.AdjLists[Curr]^ do
            begin
              Next := p^.Destination;
              if (FMates[Curr] = Next) or (FParents[Next] <> NULL_INDEX) then
                continue;
              Cost := p^.Data.Weight + FPots[Next] - FPots[Curr];
              if Cost >= ZeroWeight then
                begin
                  if FMates[Next] = NULL_INDEX then
                    begin
                      FParents[Next] := Curr;
                      exit(Next);
                    end
                  else
                    if not FVisited[Next] then
                      begin
                        FParents[Next] := Curr;
                        FQueue[qTail] := Next;
                        Inc(qTail);
                      end;
                end
              else
                if Cost > aDelta then
                  aDelta := Cost;
            end;
        end
      else
        begin
          Next := FMates[Curr];
          FParents[Next] := Curr;
          FQueue[qTail] := Next;
          Inc(qTail);
        end;
    end;
  Result := NULL_INDEX;
end;

procedure TGWeightedGraph.TKuhnMatch.AlternatePath(aRoot: SizeInt);
var
  Mate, tmp: SizeInt;
begin
  repeat
    Mate := FParents[aRoot];
    tmp := FMates[Mate];
    Match(aRoot, Mate);
    aRoot := tmp;
  until aRoot = NULL_INDEX;
end;

function TGWeightedGraph.TKuhnMatch.TryMatch(var aDelta: TWeight): SizeInt;
var
  vL, vR: SizeInt;
begin
  aDelta := InfWeight;
  FVisited.ClearBits;
  ClearParents;
  Result := 0;
  for vL in FWhites do
    if FMates[vL] = NULL_INDEX then
      begin
        vR := FindAugmentPath(vL, aDelta);
        if vR <> NULL_INDEX then
          begin
            AlternatePath(vR);
            Inc(Result);
          end;
      end;
end;

function TGWeightedGraph.TKuhnMatch.TryMatchMax(var aDelta: TWeight): SizeInt;
var
  vL, vR: SizeInt;
begin
  aDelta := NegInfWeight;
  FVisited.ClearBits;
  ClearParents;
  Result := 0;
  for vL in FWhites do
    if FMates[vL] = NULL_INDEX then
      begin
        vR := FindAugmentPathMax(vL, aDelta);
        if vR <> NULL_INDEX then
          begin
            AlternatePath(vR);
            Inc(Result);
          end;
      end;
end;

procedure TGWeightedGraph.TKuhnMatch.CorrectPots(aDelta: TWeight);
var
  I: SizeInt;
begin
  for I in FVisited do
    FPots[I] += aDelta;
end;

procedure TGWeightedGraph.TKuhnMatch.KuhnMatch;
var
  Matched: SizeInt;
  Delta: TWeight;
begin
  Delta := InfWeight;
  repeat
    repeat
      Matched := TryMatch(Delta);
      FMatchCount += Matched;
    until Matched = 0;
    if Delta < InfWeight then
      CorrectPots(Delta)
    else
      break;
  until False;
end;

procedure TGWeightedGraph.TKuhnMatch.KuhnMatchMax;
var
  Matched: SizeInt;
  Delta: TWeight;
begin
  Delta := NegInfWeight;
  repeat
    repeat
      Matched := TryMatchMax(Delta);
      FMatchCount += Matched;
    until Matched = 0;
    if Delta > NegInfWeight then
      CorrectPots(Delta)
    else
      break;
  until False;
end;

function TGWeightedGraph.TKuhnMatch.CreateEdges: TEdgeArray;
var
  I, J: SizeInt;
  d: TEdgeData;
begin
  System.SetLength(Result, FMatchCount);
  J := 0;
  d := DefaultEdgeData;
  for I in FWhites do
    if FMates[I] <> NULL_INDEX then
      begin
        FGraph.GetEdgeDataI(I, FMates[I], d);
        Result[J] := TWeightEdge.Create(I, FMates[I], d.Weight);
        Inc(J);
      end;
end;

function TGWeightedGraph.TKuhnMatch.GetMinWeightMatch(aGraph: TGWeightedGraph; constref w, g: TIntArray): TEdgeArray;
begin
  Init(aGraph, w, g);
  KuhnMatch;
  Result := CreateEdges;
end;

function TGWeightedGraph.TKuhnMatch.GetMaxWeightMatch(aGraph: TGWeightedGraph; constref w, g: TIntArray): TEdgeArray;
begin
  InitMax(aGraph, w, g);
  KuhnMatchMax;
  Result := CreateEdges;
end;

{ TGWeightedGraph.TNIMinCutHelper.TNiEdge }

constructor TGWeightedGraph.TNIMinCutHelper.TNiEdge.Create(aTarget: SizeInt; w: TWeight);
begin
  Target := aTarget;
  Weight := w;
end;

{ TGWeightedGraph.TNIMinCutHelper }

procedure TGWeightedGraph.TNIMinCutHelper.ClearMarks;
var
  I: SizeInt;
  p: TNiAdjList.PEntry;
begin
  for I in FExistNodes do
    for p in FGraph[I] do
      p^.Scanned := False;
end;

procedure TGWeightedGraph.TNIMinCutHelper.Init(aGraph: TGWeightedGraph);
var
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FGraph, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FGraph[I].EnsureCapacity(aGraph.DegreeI(I));
      for p in aGraph.AdjLists[I]^ do
        FGraph[I].Add(TNiEdge.Create(p^.Destination, p^.Data.Weight));
    end;
  FQueue := TPairHeapMax.Create(aGraph.VertexCount);
  FExistNodes.InitRange(aGraph.VertexCount);
  FInQueue.Size := aGraph.VertexCount;
  FBestCut := InfWeight;
  FCuts := nil;
end;

procedure TGWeightedGraph.TNIMinCutHelper.Init2(aGraph: TGWeightedGraph);
var
  I: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(FGraph, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    begin
      FGraph[I].EnsureCapacity(aGraph.DegreeI(I));
      for p in aGraph.AdjLists[I]^ do
        FGraph[I].Add(TNiEdge.Create(p^.Destination, p^.Data.Weight));
    end;
  System.SetLength(FCuts, aGraph.VertexCount);
  for I := 0 to Pred(aGraph.VertexCount) do
    FCuts[I].Add(I);
  FQueue := TPairHeapMax.Create(aGraph.VertexCount);
  FExistNodes.InitRange(aGraph.VertexCount);
  FInQueue.Size := aGraph.VertexCount;
  FBestCut := InfWeight;
end;

procedure TGWeightedGraph.TNIMinCutHelper.ShrinkEdge(aSource, aTarget: SizeInt);
var
  I: SizeInt;
  p: PNiEdge;
  Edge: TNiEdge;
begin
  FGraph[aSource].Remove(aTarget);
  FGraph[aTarget].Remove(aSource);
  FGraph[aSource].AddAll(FGraph[aTarget]);
  for p in FGraph[aTarget] do
    begin
      I := p^.Target;
      Edge := p^;
      FGraph[I].Remove(aTarget);
      Edge.Target := aSource;
      FGraph[I].Add(Edge);
    end;
  Finalize(FGraph[aTarget]);
  FExistNodes[aTarget] := False;
  if FCuts <> nil then
    begin
      while FCuts[aTarget].TryPop(I) do
        FCuts[aSource].Push(I);
      Finalize(FCuts[aTarget]);
    end;
end;

procedure TGWeightedGraph.TNIMinCutHelper.ScanFirstSearch;
var
  I: SizeInt;
  p: PNiEdge;
  Item: TWeightItem;
begin
  ClearMarks;
  FInQueue.Join(FExistNodes);
  for I in FExistNodes do
    FQueue.Enqueue(I, TWeightItem.Create(I, ZeroWeight));
  while FQueue.Count > 1 do
    begin
      I := FQueue.Dequeue.Index;
      FInQueue[I] := False;
      for p in FGraph[I] do
        if FInQueue[p^.Target] then
          begin
            Item := FQueue.Peek(p^.Target);
            Item.Weight += p^.Weight;
            FQueue.Update(p^.Target, Item);
            p^.Scanned := True;
            p^.ScanRank := Item.Weight;
          end;
    end;
  Item := FQueue.Dequeue;
  FInQueue[Item.Index] := False;
  if Item.Weight < FBestCut then
    begin
      FBestCut := Item.Weight;
      if FCuts <> nil then
        FBestSet.Assign(FCuts[Item.Index]);
    end;
end;

procedure TGWeightedGraph.TNIMinCutHelper.Shrink;
var
  I: SizeInt;
  p: PNiEdge;
  Pair: TIntPair;
begin
  ScanFirstSearch;
  for I in FExistNodes do
    for p in FGraph[I] do
      if p^.Scanned and (p^.ScanRank >= FBestCut) then
        FEdgeQueue.Enqueue(TIntPair.Create(I, p^.Target));
  while FEdgeQueue.TryDequeue(Pair) do
    if FExistNodes[Pair.Left] and FExistNodes[Pair.Right] then
      ShrinkEdge(Pair.Left, Pair.Right);
end;

function TGWeightedGraph.TNIMinCutHelper.GetMinCut(aGraph: TGWeightedGraph): TWeight;
begin
  Init(aGraph);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
end;

function TGWeightedGraph.TNIMinCutHelper.GetMinCut(aGraph: TGWeightedGraph; out aCut: TIntSet): TWeight;
begin
  Init2(aGraph);
  while FExistNodes.PopCount >= 2 do
    Shrink;
  Result := FBestCut;
  aCut.Assign(FBestSet);
end;

{ TGWeightedGraph }

function TGWeightedGraph.GetApproxMaxWeightMatching: TEdgeArray;
var
  Nodes: TINodeQueue;
  Matched: TBitVector;
  Node: TINode;
  p: PAdjItem;
  I, Size, s, d: SizeInt;
  w: TWeight;
begin
  Nodes := TINodeQueue.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    {%H-}Nodes.Enqueue(I, TINode.Create(I, DegreeI(I)));
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  Size := 0;
  while Nodes.TryDequeue(Node) do
    if not Matched[{%H-}Node.Index] then
      begin
        s := Node.Index;
        d := NULL_INDEX;
        w := ZeroWeight;
        for p in AdjLists[s]^ do // find adjacent node with max weight
          begin
            I := p^.Destination;
            if not Matched[I] then
              begin
                Node := Nodes.Peek(I);
                if  p^.Data.Weight > w then
                  begin
                    w := p^.Data.Weight;
                    d := I;
                  end;
                Dec(Node.Data);
                Nodes.Update(I, Node);
              end;
          end;
        if d <> NULL_INDEX then // node found
          begin
            for p in AdjLists[d]^ do
              begin
                I := p^.Destination;
                if (I <> s) and not Matched[I] then
                  begin
                    Node := Nodes.Peek(I);
                    Dec(Node.Data);
                    Nodes.Update(I, Node);
                  end;
              end;
            Matched[s] := True;
            Matched[d] := True;
            Nodes.Remove(d);
            if System.Length(Result) = Size then
              System.SetLength(Result, Size shl 1);
            Result[Size] := TWeightEdge.Create(s, d, w);
            Inc(Size);
          end;
      end;
  System.SetLength(Result, Size);
end;

function TGWeightedGraph.GetApproxMinWeightMatching: TEdgeArray;
var
  Nodes: TINodeQueue;
  Matched: TBitVector;
  Node: TINode;
  p: PAdjItem;
  I, Size, s, d: SizeInt;
  w: TWeight;
begin
  Nodes := TINodeQueue.Create(VertexCount);
  for I := 0 to Pred(VertexCount) do
    {%H-}Nodes.Enqueue(I, TINode.Create(I, DegreeI(I)));
  Matched.Size := VertexCount;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  Size := 0;
  while Nodes.TryDequeue(Node) do
    if not Matched[{%H-}Node.Index] then
      begin
        s := Node.Index;
        d := NULL_INDEX;
        w := InfWeight;
        for p in AdjLists[s]^ do // find adjacent node with min weight
          begin
            I := p^.Destination;
            if not Matched[I] then
              begin
                Node := Nodes.Peek(I);
                if  p^.Data.Weight < w then
                  begin
                    w := p^.Data.Weight;
                    d := I;
                  end;
                Dec(Node.Data);
                Nodes.Update(I, Node);
              end;
          end;
        if d <> NULL_INDEX then // node found
          begin
            for p in AdjLists[d]^ do
              begin
                I := p^.Destination;
                if (I <> s) and not Matched[I] then
                  begin
                    Node := Nodes.Peek(I);
                    Dec(Node.Data);
                    Nodes.Update(I, Node);
                  end;
              end;
            Matched[s] := True;
            Matched[d] := True;
            Nodes.Remove(d);
            if System.Length(Result) = Size then
              System.SetLength(Result, Size shl 1);
            Result[Size] := TWeightEdge.Create(s, d, w);
            Inc(Size);
          end;
      end;
  System.SetLength(Result, Size);
end;

function TGWeightedGraph.GetTrivialMinCut(out aCutSet: TIntSet; out aCutWeight: TWeight): Boolean;
var
  d: TEdgeData;
begin
  {%H-}aCutSet.MakeEmpty;
  if not Connected or (VertexCount < 2) then
    begin
      aCutWeight := ZeroWeight;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := DefaultEdgeData;
      GetEdgeDataI(0, 1, d);
      aCutWeight := d.Weight;
      aCutSet.Add(0);
      exit(True);
    end;
  Result := False;
end;

function TGWeightedGraph.GetTrivialMinCut(out aCut: TWeight): Boolean;
var
  d: TEdgeData;
begin
  if not Connected or (VertexCount < 2) then
    begin
      aCut := ZeroWeight;
      exit(True);
    end;
  if VertexCount = 2 then
    begin
      d := DefaultEdgeData;
      GetEdgeDataI(0, 1, d);
      aCut := d.Weight;
      exit(True);
    end;
  Result := False;
end;

function TGWeightedGraph.StoerWagner(out aCut: TIntSet): TWeight;
var
  Queue: TPairHeapMax;
  g: array of TSWAdjList;
  Cuts: array of TIntSet;
  vRemains, vInQueue: TBoolVector;
  Phase, Prev, Last, I: SizeInt;
  p: PAdjItem;
  pItem: ^TWeightItem;
  NextItem: TWeightItem;
begin
  //initialize
  System.SetLength(g, VertexCount);
  for I := 0 to Pred(VertexCount) do
    begin
      g[I].EnsureCapacity(DegreeI(I));
      for p in AdjLists[I]^ do
        g[I].Add(TWeightItem.Create(p^.Destination, p^.Data.Weight));
    end;
  System.SetLength(Cuts, VertexCount);
  for I := 0 to Pred(VertexCount) do
    Cuts[I].Add(I);
  Queue := TPairHeapMax.Create(VertexCount);
  vRemains.InitRange(VertexCount);
  vInQueue.Size := VertexCount;
  Result := InfWeight;
  //n-2 phases
  for Phase := 1 to Pred(VertexCount) do
    begin
      vInQueue.Join(vRemains);
      for I in vRemains do
        Queue.Enqueue(I, TWeightItem.Create(I, ZeroWeight));
      while Queue.Count > 1 do
        begin
          Prev := Queue.Dequeue.Index;
          vInQueue[Prev] := False;
          for pItem in g[Prev] do
            if vInQueue[pItem^.Index] then
              begin
                NextItem := Queue.Peek(pItem^.Index);
                NextItem.Weight += pItem^.Weight;
                Queue.Update(pItem^.Index, NextItem);
              end;
        end;
      NextItem := Queue.Dequeue;
      Last := NextItem.Index;
      vInQueue[NextItem.Index] := False;
      if Result > NextItem.Weight then
        begin
          Result := NextItem.Weight;
          aCut.Assign(Cuts[Last]);
        end;
      while Cuts[Last].TryPop(I) do
        Cuts[Prev].Push(I);
      Finalize(Cuts[Last]);
      vRemains[Last] := False;
      //merge last two vertices, remain Prev
      g[Prev].Remove(Last);
      g[Last].Remove(Prev);
      g[Prev].AddAll(g[Last]);
      for pItem in g[Last] do
        begin
          I := pItem^.Index;
          NextItem := pItem^;
          g[I].Remove(Last);
          NextItem.Index := Prev;
          g[I].Add(NextItem);
        end;
      Finalize(g[Last]);
    end;
end;

function TGWeightedGraph.CreateEdgeArray: TEdgeArray;
var
  I, J: SizeInt;
  p: PAdjItem;
begin
  System.SetLength(Result, EdgeCount);
  J := 0;
  for I := 0 to Pred(VertexCount) do
    for p in AdjLists[I]^ do
      if p^.Destination > I then
        begin
          Result[J] := TWeightEdge.Create(I, p^.Destination, p^.Data.Weight);
          Inc(J);
        end;
end;

class function TGWeightedGraph.InfWeight: TWeight;
begin
  Result := TPathHelper.InfWeight;
end;

class function TGWeightedGraph.NegInfWeight: TWeight;
begin
  Result := TPathHelper.NegInfWeight;
end;

class function TGWeightedGraph.ZeroWeight: TWeight;
begin
  Result := TPathHelper.ZeroWeight;
end;

class function TGWeightedGraph.TotalWeight(constref aEdges: TEdgeArray): TWeight;
var
  e: TWeightEdge;
begin
  Result := ZeroWeight;
  for e in aEdges do
    Result += e.Weight;
end;

function TGWeightedGraph.ContainsNegWeightEdge: Boolean;
var
  e: TEdge;
begin
  for e in DistinctEdges do
    if e.Data.Weight < ZeroWeight then
      exit(True);
  Result := False;
end;

function TGWeightedGraph.SeparateGraph(constref aVertex: TVertex): TGWeightedGraph;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TGWeightedGraph.SeparateGraphI(aIndex: SizeInt): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TGWeightedGraph.SubgraphFromVertexList(constref aList: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignVertexList(Self, aList);
end;

function TGWeightedGraph.SubgraphFromTree(constref aTree: TIntArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignTree(Self, aTree);
end;

function TGWeightedGraph.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TGWeightedGraph.Clone: TGWeightedGraph;
begin
  Result := TGWeightedGraph.Create;
  Result.AssignGraph(Self);
end;

function TGWeightedGraph.MinPathsMap(constref aSrc: TVertex): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc));
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt): TWeightArray;
begin
  CheckIndexRange(aSrc);
  Result := TPathHelper.DijkstraSssp(Self, aSrc);
end;

function TGWeightedGraph.MinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray): TWeightArray;
begin
  Result := MinPathsMapI(IndexOf(aSrc), aPathTree);
end;

function TGWeightedGraph.MinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray): TWeightArray;
begin
  CheckIndexRange(aSrc);
  Result := TPathHelper.DijkstraSssp(Self, aSrc, aPathTree);
end;

function TGWeightedGraph.FindMinPathsMap(constref aSrc: TVertex; out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  Result := TPathHelper.SpfaSssp(Self, aSrc, aWeights);
end;

function TGWeightedGraph.FindMinPathsMap(constref aSrc: TVertex; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  Result := FindMinPathsMapI(IndexOf(aSrc), aPathTree, aWeights);
end;

function TGWeightedGraph.FindMinPathsMapI(aSrc: SizeInt; out aPathTree: TIntArray;
  out aWeights: TWeightArray): Boolean;
begin
  CheckIndexRange(aSrc);
  Result := TPathHelper.SpfaSssp(Self, aSrc, aPathTree, aWeights);
end;

function TGWeightedGraph.MinPathWeight(constref aSrc, aDst: TVertex): TWeight;
begin
  Result := MinPathWeightI(IndexOf(aSrc), IndexOf(aDst));
end;

function TGWeightedGraph.MinPathWeightI(aSrc, aDst: SizeInt): TWeight;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TPathHelper.DijkstraPath(Self, aSrc, aDst);
end;

function TGWeightedGraph.MinPath(constref aSrc, aDst: TVertex; out aWeight: TWeight): TIntArray;
begin
  Result := MinPathI(IndexOf(aSrc), IndexOf(aDst), aWeight);
end;

function TGWeightedGraph.MinPathI(aSrc, aDst: SizeInt; out aWeight: TWeight): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TPathHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.FindMinPath(constref aSrc, aDst: TVertex; out aPath: TIntArray;
  out aWeight: TWeight): Boolean;
begin
  Result := FindMinPathI(IndexOf(aSrc), IndexOf(aDst), aPath, aWeight);
end;

function TGWeightedGraph.FindMinPathI(aSrc, aDst: SizeInt; out aPath: TIntArray; out aWeight: TWeight): Boolean;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  Result := TPathHelper.SpfaPath(Self, aSrc, aDst, aPath, aWeight);
end;

function TGWeightedGraph.MinPathAStar(constref aSrc, aDst: TVertex; out aWeight: TWeight;
  aEst: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aSrc), aWeight, aEst);
end;

function TGWeightedGraph.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: TWeight; aEst: TEstimate): TIntArray;
begin
  CheckIndexRange(aSrc);
  CheckIndexRange(aDst);
  if aEst <> nil then
    Result := TPathHelper.AStar(Self, aSrc, aDst, aWeight, aEst)
  else
    Result := TPathHelper.DijkstraPath(Self, aSrc, aDst, aWeight);
end;

function TGWeightedGraph.MinSpanningTreeKrus(out aTotalWeight: TWeight): TIntArray;
var
  e: TWeightEdge;
  LocEdges: TEdgeArray;
  Dsu: TDisjointSetUnion;
begin
  LocEdges := CreateEdgeArray;
  TEdgeHelper.Sort(LocEdges);
  Result := CreateIntArray;
  Dsu.Size := VertexCount;
  aTotalWeight := ZeroWeight;
  for e in LocEdges do
    if Dsu.Join(e.Source, e.Destination)  then
      begin
        Result[e.Destination] := e.Source;
        aTotalWeight += e.Weight;
      end;
end;

function TGWeightedGraph.MinSpanningTreePrim(out aTotalWeight: TWeight): TIntArray;
var
  Visited: TBitVector;
  Queue: TPairingHeap;
  I, Curr: SizeInt;
  Item: TWeightItem;
  p: PAdjItem;
begin
  Result := CreateIntArray;
  Queue := TPairingHeap.Create(VertexCount);
  Visited.Size := VertexCount;
  aTotalWeight := 0;
  for I := 0 to Pred(VertexCount) do
    if not Visited[I] then
      begin
        Queue.Enqueue(I, TWeightItem.Create(0, ZeroWeight));
        while Queue.TryDequeue(Item) do
          begin
            Curr := {%H-}Item.Index;
            aTotalWeight += Item.Weight;
            Visited[Curr] := True;
            for p in AdjLists[Curr]^ do
              begin
                if Queue.NotUsed(p^.Key) then
                  begin
                    Queue.Enqueue(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                    Result[p^.Key] := Curr;
                  end
                else
                  if not Visited[p^.Key] and (p^.Data.Weight < Queue.Peek(p^.Key).Weight) then
                    begin
                      Queue.Update(p^.Key, TWeightItem.Create(p^.Key, p^.Data.Weight));
                      Result[p^.Key] := Curr;
                    end;
              end;
          end;
      end;
end;

function TGWeightedGraph.FindBipartiteMinWeightMatching(out aMatch: TEdgeArray): Boolean;
var
  Helper: TKuhnMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.GetMinWeightMatch(Self, w, g);
  Result := True;
end;

function TGWeightedGraph.FindBipartiteMaxWeightMatching(out aMatch: TEdgeArray): Boolean;
var
  Helper: TKuhnMatch;
  w, g: TIntArray;
begin
  if not IsBipartite(w, g) then
    exit(False);
  aMatch := Helper.GetMaxWeightMatch(Self, w, g);
  Result := True;
end;

function TGWeightedGraph.ApproxMaxWeightMatching: TEdgeArray;
var
  d: TEdgeData;
begin
  if VertexCount < 2 then
    exit([]);
  if (VertexCount = 2) and Connected then
    begin
      GetEdgeDataI(0, 1, d);
      exit([TWeightEdge.Create(0, 1, {%H-}d.Weight)]);
    end;
  Result := GetApproxMaxWeightMatching;
end;

function TGWeightedGraph.ApproxMinWeightMatching: TEdgeArray;
var
  d: TEdgeData;
begin
  if VertexCount < 2 then
    exit([]);
  if (VertexCount = 2) and Connected then
    begin
      GetEdgeDataI(0, 1, d);
      exit([TWeightEdge.Create(0, 1, {%H-}d.Weight)]);
    end;
  Result := GetApproxMinWeightMatching;
end;

function TGWeightedGraph.MinWeightCutSW(out aCut: TCut): TWeight;
var
  Cut: TIntSet;
  B: TBoolVector;
  I: SizeInt;
begin
  if not GetTrivialMinCut(Cut, Result) then
    Result := StoerWagner(Cut);
  B.InitRange(VertexCount);
  for I in Cut do
    B[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := B.ToArray;
end;

function TGWeightedGraph.MinWeightCutNI: TWeight;
var
  Helper: TNIMinCutHelper;
begin
  if not GetTrivialMinCut(Result) then
    Result := Helper.GetMinCut(Self);
end;

function TGWeightedGraph.MinWeightCutNI(out aCut: TCut): TWeight;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Total: TBoolVector;
  I: SizeInt;
begin
  if not GetTrivialMinCut(Cut, Result) then
    Result := Helper.GetMinCut(Self, Cut);
  Total.InitRange(VertexCount);
  for I in Cut do
    Total[I] := False;
  aCut.A := Cut.ToArray;
  aCut.B := Total.ToArray;
end;

function TGWeightedGraph.CrossMinWeightCut: TEdgeArray;
var
  Helper: TNIMinCutHelper;
  Cut: TIntSet;
  Left, Right: TBoolVector;
  I, J: SizeInt;
  p: PAdjItem;
  d: TEdgeData;
begin
  if not Connected or (VertexCount < 2) then
    exit([]);
  d := DefaultEdgeData;
  if VertexCount = 2 then
    begin
      GetEdgeDataI(0, 1, d);
      exit([TWeightEdge.Create(0, 1, d.Weight)]);
    end;
  Helper.GetMinCut(Self, Cut);
  if Cut.Count <= VertexCount shr 1 then
    begin
      Left.Size := VertexCount;
      Right.InitRange(VertexCount);
      for I in Cut do
        begin
          Left[I] := True;
          Right[I] := False;
        end;
    end
  else
    begin
      Right.Size := VertexCount;
      Left.InitRange(VertexCount);
      for I in Cut do
        begin
          Right[I] := True;
          Left[I] := False;
        end;
    end;
  System.SetLength(Result, Cut.Count);
  J := 0;
  for I in Left do
    for p in AdjLists[I]^ do
      if Right[p^.Destination] then
        begin
          GetEdgeDataI(I, p^.Destination, d);
          if I < p^.Destination then
            Result[J] := TWeightEdge.Create(I, p^.Destination, d.Weight)
          else
            Result[J] := TWeightEdge.Create(p^.Destination, I, d.Weight);
          Inc(J);
        end;
end;

{ TRealPointEdge }

constructor TRealPointEdge.Create(const aWeight: ValReal);
begin
  Weight := aWeight;
end;

{ TPointsChart }

procedure TPointsChart.OnAddEdge(constref aSrc, aDst: TPoint; aData: Pointer);
begin
  PEdgeData(aData)^.Weight := aSrc.Distance(aDst);
end;

procedure TPointsChart.WritePoint(aStream: TStream; constref aValue: TPoint);
var
  p: TPoint;
begin
  p.X := NtoLE(aValue.X);
  p.Y := NtoLE(aValue.Y);
  aStream.WriteBuffer(p, SizeOf(p));
end;

procedure TPointsChart.ReadPoint(aStream: TStream; out aValue: TPoint);
begin
  aStream.ReadBuffer(aValue{%H-}, SizeOf(aValue));
  aValue.X := LEtoN(aValue.X);
  aValue.Y := LEtoN(aValue.Y);
end;

class function TPointsChart.Distance(constref aSrc, aDst: TPoint): ValReal;
begin
  Result := aSrc.Distance(aDst);
end;

function TPointsChart.AddEdge(constref aSrc, aDst: TPoint): Boolean;
begin
  Result := inherited AddEdge(aSrc, aDst, TRealPointEdge.Create(aSrc.Distance(aDst)));
end;

function TPointsChart.AddEdgeI(aSrc, aDst: SizeInt): Boolean;
begin
  Result := inherited AddEdgeI(aSrc, aDst, TRealPointEdge.Create(Items[aSrc].Distance(Items[aDst])));
end;

function TPointsChart.EnsureConnected: SizeInt;
begin
  Result := inherited EnsureConnected(@OnAddEdge);
end;

function TPointsChart.RemoveCutPoints(constref aRoot: TPoint): SizeInt;
begin
  Result := inherited RemoveCutPoints(aRoot, @OnAddEdge);
end;

function TPointsChart.RemoveCutPointsI(aRoot: SizeInt): SizeInt;
begin
  Result := inherited RemoveCutPointsI(aRoot, @OnAddEdge);
end;

function TPointsChart.EnsureBiconnected: SizeInt;
begin
  Result := inherited EnsureBiconnected(@OnAddEdge);
end;

procedure TPointsChart.SaveToStream(aStream: TStream);
begin
  inherited SaveToStream(aStream, @WritePoint, nil);
end;

procedure TPointsChart.LoadFromStream(aStream: TStream);
var
  I, J: SizeInt;
begin
  inherited LoadFromStream(aStream, @ReadPoint, nil);
  for I := 0 to Pred(VertexCount) do
    for J in AdjVerticesI(I) do
      SetEdgeDataI(I, J, TRealPointEdge.Create(Distance(Items[I], Items[J])));
end;

procedure TPointsChart.SaveToFile(const aFileName: string);
begin
   inherited SaveToFile(aFileName, @WritePoint, nil);
end;

procedure TPointsChart.LoadFromFile(const aFileName: string);
begin
  inherited LoadFromFile(aFileName, @ReadPoint, nil);
end;

function TPointsChart.SeparateGraph(aVertex: TPoint): TPointsChart;
begin
  Result := SeparateGraphI(IndexOf(aVertex));
end;

function TPointsChart.SeparateGraphI(aIndex: SizeInt): TPointsChart;
begin
  Result := TPointsChart.Create;
  if SeparateCount > 1 then
    Result.AssignSeparate(Self, aIndex)
  else
    Result.AssignGraph(Self);
end;

function TPointsChart.SubgraphFromVertexList(constref aList: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignVertexList(Self, aList);
end;

function TPointsChart.SubgraphFromTree(constref aTree: TIntArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignTree(Self, aTree);
end;

function TPointsChart.SubgraphFromEdges(constref aEdges: TIntEdgeArray): TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignEdges(Self, aEdges);
end;

function TPointsChart.Clone: TPointsChart;
begin
  Result := TPointsChart.Create;
  Result.AssignGraph(Self);
end;

function TPointsChart.MinPathAStar(constref aSrc, aDst: TPoint; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  Result := MinPathAStarI(IndexOf(aSrc), IndexOf(aDst), aWeight, aHeur);
end;

function TPointsChart.MinPathAStarI(aSrc, aDst: SizeInt; out aWeight: ValReal; aHeur: TEstimate): TIntArray;
begin
  if aHeur = nil then
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, @Distance)
  else
    Result := inherited MinPathAStarI(aSrc, aDst, aWeight, aHeur);
end;

end.

