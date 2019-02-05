{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic vector implementations.                                         *
*                                                                           *
*   Copyright(c) 2018-2019 A.Koverdyaev(avk)                                *
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
unit LGVector;

{$mode objfpc}{$H+}
{$INLINE ON}{$WARN 6058 off : }
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses

  SysUtils,
  math,
  LGUtils,
  {%H-}LGHelpers,
  LGArrayHelpers,
  LGAbstractContainer,
  LGStrConst;

type

  generic TGVector<T> = class(specialize TGCustomArrayContainer<T>)
  public
  type
    TVector = specialize TGVector<T>;
  protected
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); virtual;
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    function  InsertArray(aIndex: SizeInt; constref a: array of T): SizeInt;
    function  InsertContainer(aIndex: SizeInt; aContainer: TSpecContainer): SizeInt;
    function  InsertEnum(aIndex: SizeInt; e: IEnumerable): SizeInt;
    procedure FastSwap(L, R: SizeInt); inline;
    function  ExtractItem(aIndex: SizeInt): T;
    function  ExtractRange(aIndex, aCount: SizeInt): TArray;
    function  DeleteItem(aIndex: SizeInt): T; virtual;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt; virtual;
    function  DoSplit(aIndex: SizeInt): TVector;
  public
  { appends aValue and returns it index; will raise ELGUpdateLock if instance in iteration }
    function  Add(constref aValue: T): SizeInt;
  { appends all elements of array and returns count of added elements;
    will raise ELGUpdateLock if instance in iteration }
    function  AddAll(constref a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration}
    procedure Insert(aIndex: SizeInt; constref aValue: T);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
  { inserts all elements of array a into position aIndex and returns count of inserted elements;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration }
    function  InsertAll(aIndex: SizeInt; constref a: array of T): SizeInt;
  { inserts all elements of e into position aIndex and returns count of inserted elements;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration}
    function  InsertAll(aIndex: SizeInt; e: IEnumerable): SizeInt;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  ExtractAll(aIndex, aCount: SizeInt): TArray;
  { deletes value in position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    procedure Delete(aIndex: SizeInt);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryDelete(aIndex: SizeInt): Boolean;
  { deletes aCount elements(if possible) starting from aIndex and returns those count;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt;
  { will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration}
    function  Split(aIndex: SizeInt): TVector;
  { will return False if aIndex out of bounds or instance in iteration }
    function  TrySplit(aIndex: SizeInt; out aValue: TVector): Boolean;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  end;

  { TGObjectVector
    note: for equality comparision of items uses TObjectHelper from LGHelpers }
  generic TGObjectVector<T: class> = class(specialize TGVector<T>)
  public
  type
    TObjectVector = specialize TGObjectVector<T>;
  private
    FOwnsObjects: Boolean;
  protected
    procedure SetItem(aIndex: SizeInt; const aValue: T); override;
    procedure DoClear; override;
    function  DeleteItem(aIndex: SizeInt): T; override;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt; override;
    function  DoSplit(aIndex: SizeInt): TObjectVector;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(constref A: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
  { will raise EArgumentOutOfRangeException if aIndex out of bounds }
    function  Split(aIndex: SizeInt): TObjectVector;
  { will return False if aIndex out of bounds }
    function  TrySplit(aIndex: SizeInt; out aValue: TObjectVector): Boolean;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGThreadVector<T> = class
  public
  type
    TVector = specialize TGVector<T>;
  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
  { returns reference to encapsulated vector, after use this reference one must call UnLock }
    function  Lock: TVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(constref aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt): Boolean;
  end;

  generic TGLiteVector<T> = record
  private
  type
    TBuffer = specialize TGLiteDynBuffer<T>;

  public
  type
    TEnumerator = TBuffer.TEnumerator;
    TMutables    = TBuffer.TMutables;
    TReverse    = TBuffer.TReverse;
    PItem       = TBuffer.PItem;
    TArray      = TBuffer.TArray;

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetMutable(aIndex: SizeInt): PItem;
    procedure SetItem(aIndex: SizeInt; const aValue: T); inline;
    procedure InsertItem(aIndex: SizeInt; constref aValue: T);
    function  DeleteItem(aIndex: SizeInt): T;
    function  ExtractRange(aIndex, aCount: SizeInt): TArray;
    function  DeleteRange(aIndex, aCount: SizeInt): SizeInt;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
  { appends aValue and returns it index }
    function  Add(constref aValue: T): SizeInt;
    function  AddAll(constref a: array of T): SizeInt;
    function  AddAll(constref aVector: TGLiteVector): SizeInt;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; constref aValue: T); inline;
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean; inline;
  { deletes and returns value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean; inline;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  ExtractAll(aIndex, aCount: SizeInt): TArray; inline;
  { deletes aCount elements(if possible) starting from aIndex;
    returns count of deleted elements;
    will raise ELGListError if aIndex out of bounds }
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt; inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Mutable[aIndex: SizeInt]: PItem read GetMutable;
  end;

  generic TGLiteThreadVector<T> = class
  public
  type
    TVector = specialize TGLiteVector<T>;
    PVector = ^TVector;

  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    function  Lock: PVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(constref aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
  end;

  generic TGLiteObjectVector<T: class> = record
  private
  type
    TVector = specialize TGLiteVector<T>;

  public
  type
    TEnumerator = TVector.TEnumerator;
    TReverse    = TVector.TReverse;
    TArray      = TVector.TArray;

  private
    FVector: TVector;
    FOwnsObjects: Boolean;
    function  GetCount: SizeInt; inline;
    function  GetCapacity: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    procedure CheckFreeItems;
    class operator Initialize(var v: TGLiteObjectVector);
    class operator Copy(constref aSrc: TGLiteObjectVector; var aDst: TGLiteObjectVector);
  public
  type
    PVector = ^TVector;
    function  InnerVector: PVector; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
  { appends aValue and returns it index }
    function  Add(constref aValue: T): SizeInt;inline;
    function  AddAll(constref a: array of T): SizeInt;
    function  AddAll(constref aVector: TGLiteObjectVector): SizeInt; inline;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; constref aValue: T); inline;
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean; inline;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean; inline;
  { extracts aCount elements(if possible) starting from aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  ExtractAll(aIndex, aCount: SizeInt): TArray; inline;
  { deletes value in position aIndex; will raise ELGListError if aIndex out of bounds}
    procedure Delete(aIndex: SizeInt); inline;
  { will return False if aIndex out of bounds }
    function  TryDelete(aIndex: SizeInt): Boolean; inline;
  { deletes aCount elements(if possible) starting from aIndex;
    returns count of deleted elements;
    will raise ELGListError if aIndex out of bounds }
    function  DeleteAll(aIndex, aCount: SizeInt): SizeInt;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectVector<T: class> = class
  public
  type
    TVector = specialize TGLiteObjectVector<T>;
    PVector = ^TVector;

  private
    FVector: TVector;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    function  Lock: PVector;
    procedure Unlock; inline;
    procedure Clear;
    function  Add(constref aValue: T): SizeInt;
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
    function  TryDelete(aIndex: SizeInt): Boolean;
  end;

  { TBoolVector: size is always a multiple of the bitness }
  TBoolVector = record
  public
  type
    PBoolVector = ^TBoolVector;

    TEnumerator = record
    private
      FValue: PBoolVector;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      FInCycle: Boolean;
      function GetCurrent: SizeInt; inline;
      function FindFirst: Boolean;
    public
      function MoveNext: Boolean; inline;
      property Current: SizeInt read GetCurrent;
    end;

    TReverseEnumerator = record
    private
      FValue: PBoolVector;
      FBitIndex,
      FLimbIndex: SizeInt;
      FCurrLimb: SizeUInt;
      FInCycle: Boolean;
      function GetCurrent: SizeInt; inline;
      function FindFirst: Boolean;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

    TReverse = record
    private
      FValue: PBoolVector;
    public
      function GetEnumerator: TReverseEnumerator; inline;
    end;

  private
  type
    TBits = array of SizeUInt;

  var
    FBits: TBits;
    function  GetBit(aIndex: SizeInt): Boolean; inline;
    function  GetSize: SizeInt; inline;
    procedure SetBit(aIndex: SizeInt; aValue: Boolean); inline;
    procedure SetSize(aValue: SizeInt);
    class function  BsfValue(aValue: SizeUInt): SizeInt; static; inline;
    class function  BsrValue(aValue: SizeUInt): SizeInt; static; inline;
    class procedure ClearBit(aIndex: SizeInt; var aValue: SizeUInt); static; inline;
    class operator  Copy(constref aSrc: TBoolVector; var aDst: TBoolVector);
  public
  type
    TIntArray = array of SizeInt;

    procedure InitRange(aRange: SizeInt);
  { enumerates indices of set bits from lowest to highest }
    function  GetEnumerator: TEnumerator; inline;
  { enumerates indices of set bits from highest down to lowest }
    function  Reverse: TReverse; inline;
  { returns an array containing the indices of the set bits }
    function  ToArray: TIntArray;
    procedure ClearBits; inline;
    procedure SetBits; inline;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean; inline;
    procedure SwapBits(var aVector: TBoolVector);
  { returns the lowest index of the set bit, -1, if no bit is set }
    function  Bsf: SizeInt;
  { returns the highest index of the set bit, -1, if no bit is set }
    function  Bsr: SizeInt;
  { returns the lowest index of the open bit, -1, if all bits are set }
    function  Lob: SizeInt;
    function  Intersecting(constref aValue: TBoolVector): Boolean;
  { returns the number of bits in the intersection with aValue }
    function  IntersectionPop(constref aValue: TBoolVector): SizeInt;
    function  Contains(constref aValue: TBoolVector): Boolean;
  { returns the number of bits that will be added when union with aValue }
    function  JoinGain(constref aValue: TBoolVector): SizeInt;
    procedure Join(constref aValue: TBoolVector);
    function  Union(constref aValue: TBoolVector): TBoolVector; inline;
    procedure Subtract(constref aValue: TBoolVector);
    function  Difference(constref aValue: TBoolVector): TBoolVector; inline;
    procedure Intersect(constref aValue: TBoolVector);
    function  Intersection(constref aValue: TBoolVector): TBoolVector; inline;
  { currently size can only grow and is always multiple of BitsizeOf(SizeUInt) }
    property  Size: SizeInt read GetSize write SetSize;
  { returns count of set bits }
    function  PopCount: SizeInt;
  { read/write bit with (index < 0) or (index >= Size) will raise exception }
    property  Bits[aIndex: SizeInt]: Boolean read GetBit write SetBit; default;
  end;

  { TGVectorHelpUtil }

  generic TGVectorHelpUtil<T> = class
  private
  type
    THelper = specialize TGArrayHelpUtil<T>;
  public
  type
    TEqualityCompare = THelper.TEqualCompare;
    TVector          = class(specialize TGVector<T>);
    TLiteVector      = specialize TGLiteVector<T>;
    class procedure Reverse(v: TVector); static; inline;
    class procedure Reverse(var v: TLiteVector); static; inline;
    class procedure RandomShuffle(v: TVector); static; inline;
    class procedure RandomShuffle(var v: TLiteVector); static; inline;
    class function  SequentSearch(v: TVector; constref aValue: T; c: TEqualityCompare): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T; c: TEqualityCompare): SizeInt;
                    static; inline;
  end;

  { TGBaseVectorHelper
      functor TCmpRel(comparision relation) must provide:
        class function Compare([const[ref]] L, R: T): SizeInt }
  generic TGBaseVectorHelper<T, TCmpRel> = class
  private
  type
    THelper = specialize TGBaseArrayHelper<T, TCmpRel>;
  public
  type
    TVector     = class(specialize TGVector<T>);
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; constref aValue: T): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; constref aValue: T): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; constref aValue: T): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean; static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector): Boolean; static;
    class function  Same(constref A, B: TLiteVector): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently it is IntroSort}
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector): TLiteVector.TArray; static; inline;
  end;

  { TGVectorHelper assumes that type T implements TCmpRel }
  generic TGVectorHelper<T> = class(specialize TGBaseVectorHelper<T, T>);

  { TGComparableVectorHelper assumes that type T defines comparision operators }
  generic TGComparableVectorHelper<T> = class
  private
  type
    THelper = specialize TGComparableArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    class procedure Reverse(v: TVector); static; inline;
    class procedure Reverse(var v: TLiteVector); static; inline;
    class procedure RandomShuffle(v: TVector); static; inline;
    class procedure RandomShuffle(var v: TLiteVector); static; inline;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; constref aValue: T): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; constref aValue: T): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; constref aValue: T): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean; static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector): Boolean; static;
    class function  Same(constref A, B: TLiteVector): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently it is IntroSort}
    class procedure Sort(v: TVector; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector): TLiteVector.TArray; static; inline;
  end;

  { TGRegularVectorHelper: with regular comparator }
  generic TGRegularVectorHelper<T> = class
  private
  type
    THelper   = specialize TGRegularArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TCompare    = specialize TGCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TCompare): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TCompare): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TCompare): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TCompare): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TCompare): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TCompare): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TCompare): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TCompare): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TCompare): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TCompare): Boolean;
                    static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if V is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is nondestuctive: creates temp copy of V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TCompare): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TCompare): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TCompare): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TCompare): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TCompare): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TCompare): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TCompare): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently it is IntroSort}
    class procedure Sort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TCompare): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TCompare): TLiteVector.TArray; static; inline;
  end;

  { TGDelegatedVectorHelper: with delegated comparator }
  generic TGDelegatedVectorHelper<T> = class
  private
  type
    THelper = specialize TGDelegatedArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TOnCompare  = specialize TGOnCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; constref aValue: T; c: TOnCompare): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T; c: TOnCompare): SizeInt; static; inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; constref aValue: T; c: TOnCompare): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; constref aValue: T; c: TOnCompare): SizeInt; static; inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TOnCompare): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector; c: TOnCompare): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TOnCompare): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TOnCompare): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TOnCompare): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TOnCompare): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TOnCompare): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TOnCompare): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TOnCompare): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TOnCompare): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TOnCompare): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TOnCompare): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TOnCompare): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TOnCompare): Boolean;
                    static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TOnCompare): Boolean;
                    static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TOnCompare): Boolean;
                    static; inline;
  { returns V's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TOnCompare): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TOnCompare): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TOnCompare): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TOnCompare): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TOnCompare): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TOnCompare): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently it is IntroSort}
    class procedure Sort(v: TVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TOnCompare; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TOnCompare): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TOnCompare): TLiteVector.TArray; static; inline;
  end;

  { TGNestedVectorHelper: with nested comparator }
  generic TGNestedVectorHelper<T> = class
  private
  type
    THelper = specialize TGNestedArrayHelper<T>;
  public
  type
    TVector     = specialize TGVector<T>;
    TLiteVector = specialize TGLiteVector<T>;
    TOptional   = specialize TGOptional<T>;
    TCompare    = specialize TGNestCompare<T>;
  { returns position of aValue in vector V, -1 if not found }
    class function  SequentSearch(v: TVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
    class function  SequentSearch(constref v: TLiteVector; constref aValue: T; c: TCompare): SizeInt; static;
                    inline;
  { returns position of aValue in SORTED vector V, -1 if not found }
    class function  BinarySearch(v: TVector; constref aValue: T; c: TCompare): SizeInt; static; inline;
    class function  BinarySearch(constref v: TLiteVector; constref aValue: T; c: TCompare): SizeInt; static;
                    inline;
  { returns position of minimal value in V, -1 if V is empty }
    class function  IndexOfMin(v: TVector; c: TCompare): SizeInt; static; inline;
    class function  IndexOfMin(constref v: TLiteVector; c: TCompare): SizeInt; static; inline;
  { returns position of maximal value in V, -1 if V is empty }
    class function  IndexOfMax(v: TVector; c: TCompare): SizeInt; static; inline;
    class function  IndexOfMax(constref v: TLiteVector; c: TCompare): SizeInt; static; inline;
  { returns smallest element of A in TOptional.Value if V is nonempty }
    class function  GetMin(v: TVector; c: TCompare): TOptional; static; inline;
    class function  GetMin(constref v: TLiteVector; c: TCompare): TOptional; static; inline;
  { returns greatest element of A in TOptional.Value if V is nonempty }
    class function  GetMax(v: TVector; c: TCompare): TOptional; static; inline;
    class function  GetMax(constref v: TLiteVector; c: TCompare): TOptional; static; inline;
  { returns True and smallest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMin(v: TVector; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindMin(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean; static; inline;
  { returns True and greatest element of A in aValue if V is nonempty, False otherwise }
    class function  FindMax(v: TVector; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindMax(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean; static; inline;
  { returns True, smallest element of V in aMin and greatest element of V in aMax, if V is nonempty,
    False otherwise }
    class function  FindMinMax(v: TVector; out aMin, aMax: T; c: TCompare): Boolean; static; inline;
    class function  FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TCompare): Boolean; static; inline;
  { returns True and V's Nth order statistic(0-based) in aValue if V is nonempty, False otherwise;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TCompare): Boolean; static; inline;
    class function  FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T; c: TCompare): Boolean;
                    static; inline;
    { returns V's Nth order statistic(0-based) in TOptional.Value if A is nonempty;
    if N < 0 then N sets to 0; if N > High(V) then N sets to High(V);
    is destuctive: changes order of elements in V }
    class function  NthSmallest(v: TVector; N: SizeInt; c: TCompare): TOptional; static; inline;
    class function  NthSmallest(constref v: TLiteVector; N: SizeInt; c: TCompare): TOptional; static; inline;
  { returns True if permutation towards nondescending state of V has done, False otherwise }
    class function  NextPermutation2Asc(v: TVector; c: TCompare): Boolean; static; inline;
    class function  NextPermutation2Asc(var v: TLiteVector; c: TCompare): Boolean; static; inline;
  { returns True if permutation towards nonascending state of V has done, False otherwise }
    class function  NextPermutation2Desc(v: TVector; c: TCompare): Boolean; static; inline;
    class function  NextPermutation2Desc(var v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nondescending }
    class function  IsNonDescending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsNonDescending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict ascending }
    class function  IsStrictAscending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsStrictAscending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is always nonascending }
    class function  IsNonAscending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsNonAscending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { note: an empty array or single element array is never strict descending}
    class function  IsStrictDescending(v: TVector; c: TCompare): Boolean; static; inline;
    class function  IsStrictDescending(constref v: TLiteVector; c: TCompare): Boolean; static; inline;
  { returns True if both A and B are identical sequence of elements }
    class function  Same(A, B: TVector; c: TCompare): Boolean; static;
    class function  Same(constref A, B: TLiteVector; c: TCompare): Boolean; static;
  { slightly optimized quicksort with random pivot selection }
    class procedure QuickSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure QuickSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { slightly modified Introsort with pseudo-median-of-9 pivot selection }
    class procedure IntroSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure IntroSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { stable, adaptive mergesort, inspired by Java Timsort }
    class procedure MergeSort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure MergeSort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { default sort algorithm, currently it is IntroSort}
    class procedure Sort(v: TVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
    class procedure Sort(var v: TLiteVector; c: TCompare; o: TSortOrder = soAsc); static; inline;
  { copies only distinct values from v }
    class function  SelectDistinct(v: TVector; c: TCompare): TVector.TArray; static; inline;
    class function  SelectDistinct(constref v: TLiteVector; c: TCompare): TVector.TArray; static; inline;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGVector }

function TGVector.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := FItems[aIndex];
end;

procedure TGVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  //CheckInIteration;
  CheckIndexRange(aIndex);
  FItems[aIndex] := aValue;
end;

procedure TGVector.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  if aIndex < ElemCount then
    begin
      ItemAdding;
      System.Move(FItems[aIndex], FItems[Succ(aIndex)], SizeOf(T) * (ElemCount - aIndex));
      System.FillChar(FItems[aIndex], SizeOf(T), 0);
      FItems[aIndex] := aValue;
      Inc(FCount);
    end
  else
    Append(aValue);
end;

function TGVector.InsertArray(aIndex: SizeInt; constref a: array of T): SizeInt;
begin
  if aIndex < ElemCount then
    begin
      Result := System.Length(a);
      if Result > 0 then
        begin
          EnsureCapacity(ElemCount + Result);
          System.Move(FItems[aIndex], FItems[aIndex + Result], SizeOf(T) * (ElemCount - aIndex));
          System.FillChar(FItems[aIndex], SizeOf(T) * Result, 0);
          TCopyArrayHelper.CopyItems(@a[0], @FItems[aIndex], Result);
          FCount += Result;
        end;
    end
  else
    Result := AppendArray(a);
end;

function TGVector.InsertContainer(aIndex: SizeInt; aContainer: TSpecContainer): SizeInt;
var
  v: T;
begin
  if aIndex < ElemCount then
    begin
      Result := aContainer.Count;
      if Result > 0 then
        begin
          EnsureCapacity(ElemCount + Result);
          System.Move(FItems[aIndex], FItems[aIndex + Result], SizeOf(T) * (ElemCount - aIndex));
          System.FillChar(FItems[aIndex], SizeOf(T) * Result, 0);
          if aContainer <> Self then
            for v in aContainer do
              begin
                FItems[aIndex] := v;
                Inc(aIndex);
              end
          else
            begin
              TCopyArrayHelper.CopyItems(@FItems[0], @FItems[aIndex], aIndex);
              TCopyArrayHelper.CopyItems(@FItems[aIndex + Result], @FItems[aIndex + aIndex], Result - aIndex);
            end;
          FCount += Result;
        end;
    end
  else
    Result := AppendContainer(aContainer);
end;

function TGVector.InsertEnum(aIndex: SizeInt; e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecContainer then
    Result := InsertContainer(aIndex, TSpecContainer(o))
  else
    Result := InsertArray(aIndex, e.ToArray);
end;

procedure TGVector.FastSwap(L, R: SizeInt);
var
  v: TFake;
begin
  v := TFake(FItems[L]);
  TFake(FItems[L]) := TFake(FItems[R]);
  TFake(FItems[R]) := v;
end;

function TGVector.ExtractItem(aIndex: SizeInt): T;
begin
  Result := FItems[aIndex];
  FItems[aIndex] := Default(T);
  Dec(FCount);
  System.Move(FItems[Succ(aIndex)], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
  System.FillChar(FItems[ElemCount], SizeOf(T), 0);
end;

function TGVector.ExtractRange(aIndex, aCount: SizeInt): TArray;
begin
  if aCount < 0 then
    aCount := 0;
  aCount := Math.Min(aCount, ElemCount - aIndex);
  System.SetLength(Result, aCount);
  if aCount > 0 then
    begin
      System.Move(FItems[aIndex], Result[0], SizeOf(T) * aCount);
      FCount -= aCount;
      System.Move(FItems[aIndex + aCount], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      System.FillChar(FItems[ElemCount], SizeOf(T) * aCount, 0);
    end;
end;

function TGVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

function TGVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, ElemCount - aIndex);
  if Result > 0 then
    begin
      for I := aIndex to Pred(aIndex + Result) do
        FItems[I] := Default(T);
      FCount -= Result;
      System.Move(FItems[aIndex + Result], FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
      System.FillChar(FItems[ElemCount], SizeOf(T) * Result, 0);
    end;
end;

function TGVector.DoSplit(aIndex: SizeInt): TVector;
var
  RCount: SizeInt;
begin
  RCount := ElemCount - aIndex;
  Result := TGVector.Create(RCount);
  System.Move(FItems[aIndex], Result.FItems[0], SizeOf(T) * RCount);
  System.FillChar(FItems[aIndex], SizeOf(T) * RCount, 0);
  Result.FCount := RCount;
  FCount -= RCount;
end;

function TGVector.Add(constref aValue: T): SizeInt;
begin
  CheckInIteration;
  Result := Append(aValue);
end;

function TGVector.AddAll(constref a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGVector.AddAll(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := AppendEnumerable(e)
  else
    begin
      Result := 0;
      e.Any;
      UpdateLockError;
    end;
end;

procedure TGVector.Insert(aIndex: SizeInt; constref aValue: T);
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  InsertItem(aIndex, aValue);
end;

function TGVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  Result := not InIteration and IndexInInsertRange(aIndex);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGVector.InsertAll(aIndex: SizeInt; constref a: array of T): SizeInt;
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  Result := InsertArray(aIndex, a);
end;

function TGVector.InsertAll(aIndex: SizeInt; e: IEnumerable): SizeInt;
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  Result := InsertEnum(aIndex, e);
end;

function TGVector.Extract(aIndex: SizeInt): T;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := ExtractItem(aIndex);
end;

function TGVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    aValue := ExtractItem(aIndex);
end;

function TGVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := ExtractRange(aIndex, aCount);
end;

procedure TGVector.Delete(aIndex: SizeInt);
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  DeleteItem(aIndex);
end;

function TGVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    DeleteItem(aIndex);
end;

function TGVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DeleteRange(aIndex, aCount);
end;

function TGVector.Split(aIndex: SizeInt): TVector;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DoSplit(aIndex);
end;

function TGVector.TrySplit(aIndex: SizeInt; out aValue: TVector): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    aValue := DoSplit(aIndex);
end;

{ TGObjectVector }

procedure TGObjectVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  //CheckInIteration;
  CheckIndexRange(aIndex);
  if OwnsObjects and not TObject.Equal(FItems[aIndex], aValue) then
    FItems[aIndex].Free;
  FItems[aIndex] := aValue;
end;

procedure TGObjectVector.DoClear;
var
  I: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    for I := 0 to Pred(ElemCount) do
      FItems[I].Free;
  inherited;
end;

function TGObjectVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := inherited DeleteItem(aIndex);
  if OwnsObjects then
    Result.Free;
end;

function TGObjectVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, ElemCount - aIndex);
  if Result > 0 then
    begin
      if OwnsObjects then
        for I := aIndex to Pred(aIndex + Result) do
          FItems[I].Free;
      FCount -= Result;
      //todo: watch later (@FItems[aIndex + Result])^
      System.Move((@FItems[aIndex + Result])^, FItems[aIndex], SizeOf(T) * (ElemCount - aIndex));
    end;
end;

function TGObjectVector.DoSplit(aIndex: SizeInt): TObjectVector;
var
  RCount: SizeInt;
begin
  RCount := ElemCount - aIndex;
  Result := TGObjectVector.Create(RCount, OwnsObjects);
  //todo: watch later (@FItems[aIndex])^
  System.Move((@FItems[aIndex])^, Result.FItems[0], SizeOf(T) * RCount);
  Result.FCount := RCount;
  FCount -= RCount;
end;

constructor TGObjectVector.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(constref A: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectVector.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

function TGObjectVector.Split(aIndex: SizeInt): TObjectVector;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := DoSplit(aIndex);
end;

function TGObjectVector.TrySplit(aIndex: SizeInt; out aValue: TObjectVector): Boolean;
begin
  Result := not InIteration and (aIndex >= 0) and (aIndex < ElemCount);
  if Result then
    aValue := DoSplit(aIndex);
end;

procedure TGThreadVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadVector.Create;
begin
  System.InitCriticalSection(FLock);
  FVector := TVector.Create;
end;

destructor TGThreadVector.Destroy;
begin
  DoLock;
  try
    FVector.Free;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGThreadVector.Lock: TVector;
begin
  Result := FVector;
  DoLock;
end;

procedure TGThreadVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGThreadVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGThreadVector.Add(constref aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGThreadVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryDelete(aIndex);
  finally
    UnLock;
  end;
end;

{ TGLiteVector }

function TGLiteVector.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteVector.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.GetMutable(aIndex: SizeInt): PItem;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := @FBuffer.FItems[aIndex]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteVector.SetItem(aIndex: SizeInt; const aValue: T);
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    FBuffer.FItems[aIndex] := aValue
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteVector.InsertItem(aIndex: SizeInt; constref aValue: T);
begin
  if aIndex < Count then
    begin
      FBuffer.ItemAdding;
      System.Move(FBuffer.FItems[aIndex], FBuffer.FItems[Succ(aIndex)], SizeOf(T) * (Count - aIndex));
      System.FillChar(FBuffer.FItems[aIndex], SizeOf(T), 0);
      FBuffer.FItems[aIndex] := aValue;
      Inc(FBuffer.FCount);
    end
  else
    Add(aValue);
end;

function TGLiteVector.DeleteItem(aIndex: SizeInt): T;
begin
  Result := FBuffer.FItems[aIndex];
  FBuffer.FItems[aIndex] := Default(T);
  Dec(FBuffer.FCount);
  System.Move(FBuffer.FItems[Succ(aIndex)], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
  System.FillChar(FBuffer.FItems[Count], SizeOf(T), 0);
end;

function TGLiteVector.ExtractRange(aIndex, aCount: SizeInt): TArray;
begin
  if aCount < 0 then
    aCount := 0;
  aCount := Math.Min(aCount, Count - aIndex);
  System.SetLength(Result, aCount);
  if aCount > 0 then
    begin
      System.Move(FBuffer.FItems[aIndex], Result[0], SizeOf(T) * aCount);
      FBuffer.FCount -= aCount;
      System.Move(FBuffer.FItems[aIndex + aCount], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
      System.FillChar(FBuffer.FItems[Count], SizeOf(T) * aCount, 0);
    end;
end;

function TGLiteVector.DeleteRange(aIndex, aCount: SizeInt): SizeInt;
var
  I: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  Result := Math.Min(aCount, Count - aIndex);
  if Result > 0 then
    begin
      for I := aIndex to Pred(aIndex + Result) do
        FBuffer.FItems[I] := Default(T);
      FBuffer.FCount -= Result;
      System.Move(FBuffer.FItems[aIndex + Result], FBuffer.FItems[aIndex], SizeOf(T) * (Count - aIndex));
      System.FillChar(FBuffer.FItems[Count], SizeOf(T) * Result, 0);
    end;
end;

function TGLiteVector.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteVector.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteVector.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteVector.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteVector.Clear;
begin
  FBuffer.Clear;
end;

function TGLiteVector.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteVector.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteVector.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteVector.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

function TGLiteVector.Add(constref aValue: T): SizeInt;
begin
  Result := FBuffer.PushLast(aValue);
end;

function TGLiteVector.AddAll(constref a: array of T): SizeInt;
var
  v: T;
  I: SizeInt;
begin
  Result := System.Length(a);
  EnsureCapacity(Count + Result);
  I := Count;
  with FBuffer do
    begin
      for v in a do
        begin
          FItems[I] := v;
          Inc(I);
        end;
      FCount += Result;
    end;
end;

function TGLiteVector.AddAll(constref aVector: TGLiteVector): SizeInt;
var
  v: T;
  I: SizeInt;
begin
  Result := aVector.Count;
  EnsureCapacity(Count + Result);
  I := Count;
  with FBuffer do
    begin
      for v in aVector do
        begin
          FItems[I] := v;
          Inc(I);
        end;
      FCount += Result;
    end;
end;

procedure TGLiteVector.Insert(aIndex: SizeInt; constref aValue: T);
begin
  if SizeUInt(aIndex) <= SizeUInt(Count) then
    InsertItem(aIndex, aValue)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) <= SizeUInt(Count);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGLiteVector.Extract(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := DeleteItem(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) < SizeUInt(Count);
  if Result then
    aValue := DeleteItem(aIndex);
end;

function TGLiteVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := ExtractRange(aIndex, aCount)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
begin
  if SizeUInt(aIndex) < SizeUInt(Count) then
    Result := DeleteRange(aIndex, aCount)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

{ TGLiteThreadVector }

procedure TGLiteThreadVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadVector.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadVector.Destroy;
begin
  DoLock;
  try
    Finalize(FVector);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGLiteThreadVector.Lock: PVector;
begin
  Result := @FVector;
  DoLock;
end;

procedure TGLiteThreadVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGLiteThreadVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.Add(constref aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadVector.TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

{ TGLiteObjectVector }

function TGLiteObjectVector.GetCount: SizeInt;
begin
  Result := FVector.Count;
end;

function TGLiteObjectVector.GetCapacity: SizeInt;
begin
  Result := FVector.Capacity;
end;

function TGLiteObjectVector.GetItem(aIndex: SizeInt): T;
begin
  Result := FVector.GetItem(aIndex);
end;

procedure TGLiteObjectVector.SetItem(aIndex: SizeInt; const aValue: T);
var
  v: T;
begin
  if OwnsObjects then
    begin
      v := FVector[aIndex];
      if not TObject.Equal(v, aValue) then
        v.Free;
    end;
  FVector.SetItem(aIndex, aValue);
end;

procedure TGLiteObjectVector.CheckFreeItems;
var
  I: SizeInt;
  InnerItems: TArray;
begin
  if OwnsObjects then
    begin
      InnerItems := FVector.FBuffer.FItems;
      for I := 0 to Pred(Count) do
        InnerItems[I].Free;
    end;
end;

class operator TGLiteObjectVector.Initialize(var v: TGLiteObjectVector);
begin
  v.OwnsObjects := True;
end;

class operator TGLiteObjectVector.Copy(constref aSrc: TGLiteObjectVector; var aDst: TGLiteObjectVector);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FVector := aSrc.FVector;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectVector.InnerVector: PVector;
begin
  Result := @FVector;
end;

function TGLiteObjectVector.GetEnumerator: TEnumerator;
begin
  Result := FVector.GetEnumerator;
end;

function TGLiteObjectVector.Reverse: TReverse;
begin
  Result := FVector.Reverse;
end;

function TGLiteObjectVector.ToArray: TArray;
begin
  Result := FVector.ToArray;
end;

procedure TGLiteObjectVector.Clear;
begin
  CheckFreeItems;
  FVector.Clear;
end;

function TGLiteObjectVector.IsEmpty: Boolean;
begin
  Result := FVector.IsEmpty;
end;

function TGLiteObjectVector.NonEmpty: Boolean;
begin
  Result := FVector.NonEmpty;
end;

procedure TGLiteObjectVector.EnsureCapacity(aValue: SizeInt);
begin
  FVector.EnsureCapacity(aValue)
end;

procedure TGLiteObjectVector.TrimToFit;
begin
  FVector.TrimToFit;
end;

function TGLiteObjectVector.Add(constref aValue: T): SizeInt;
begin
  Result := FVector.Add(aValue);
end;

function TGLiteObjectVector.AddAll(constref a: array of T): SizeInt;
begin
  Result := FVector.AddAll(a);
end;

function TGLiteObjectVector.AddAll(constref aVector: TGLiteObjectVector): SizeInt;
begin
  Result := FVector.AddAll(aVector.FVector);
end;

procedure TGLiteObjectVector.Insert(aIndex: SizeInt; constref aValue: T);
begin
  FVector.Insert(aIndex, aValue);
end;

function TGLiteObjectVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  Result := FVector.TryInsert(aIndex, aValue);
end;

function TGLiteObjectVector.Extract(aIndex: SizeInt): T;
begin
  Result := FVector.Extract(aIndex);
end;

function TGLiteObjectVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := FVector.TryExtract(aIndex, aValue);
end;

function TGLiteObjectVector.ExtractAll(aIndex, aCount: SizeInt): TArray;
begin
  Result := FVector.ExtractAll(aIndex, aCount);
end;

procedure TGLiteObjectVector.Delete(aIndex: SizeInt);
var
  v: T;
begin
  v := FVector.Extract(aIndex);
  if OwnsObjects then
    v.Free;
end;

function TGLiteObjectVector.TryDelete(aIndex: SizeInt): Boolean;
var
  v: T;
begin
  Result := FVector.TryExtract(aIndex, v);
  if Result and OwnsObjects then
    v.Free;
end;

function TGLiteObjectVector.DeleteAll(aIndex, aCount: SizeInt): SizeInt;
var
  a: TArray;
  v: T;
begin
  if OwnsObjects then
    begin
      a := FVector.ExtractAll(aIndex, aCount);
      Result := System.Length(a);
      for v in a do
        v.Free;
    end
  else
    Result := FVector.DeleteAll(aIndex, aCount);
end;

{ TGLiteThreadObjectVector }

procedure TGLiteThreadObjectVector.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectVector.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadObjectVector.Destroy;
begin
  DoLock;
  try
    Finalize(FVector);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

function TGLiteThreadObjectVector.Lock: PVector;
begin
  Result := @FVector;
  DoLock;
end;

procedure TGLiteThreadObjectVector.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGLiteThreadObjectVector.Clear;
begin
  DoLock;
  try
    FVector.Clear;
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.Add(constref aValue: T): SizeInt;
begin
  DoLock;
  try
    Result := FVector.Add(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryInsert(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryExtract(aIndex, aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectVector.TryDelete(aIndex: SizeInt): Boolean;
begin
  DoLock;
  try
    Result := FVector.TryDelete(aIndex);
  finally
    UnLock;
  end;
end;

{ TBoolVector.TEnumerator }

function TBoolVector.TEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TBoolVector.TEnumerator.FindFirst: Boolean;
var
  I: SizeInt;
begin
  I := FValue^.Bsf;
  if I >= 0 then
    begin
      FLimbIndex := I shr INT_SIZE_LOG;
      FBitIndex := I and INT_SIZE_MASK;
      FCurrLimb := FValue^.FBits[FLimbIndex];
      TBoolVector.ClearBit(FBitIndex, FCurrLimb);
      Result := True;
    end
  else
    begin
      FLimbIndex := System.Length(FValue^.FBits);
      FBitIndex := BitsizeOf(SizeUInt);
      Result := False;
    end;
end;

function TBoolVector.TEnumerator.MoveNext: Boolean;
begin
  if FInCycle then
    repeat
      FBitIndex := TBoolVector.BsfValue(FCurrLimb);
      Result := FBitIndex >= 0;
      if Result then
        TBoolVector.ClearBit(FBitIndex, FCurrLimb)
      else
        begin
          if FLimbIndex >= System.High(FValue^.FBits) then
            exit(False);
          Inc(FLimbIndex);
          FCurrLimb := FValue^.FBits[FLimbIndex];
        end;
    until Result
  else
    begin
      Result := FindFirst;
      FInCycle := True;
    end;
end;

{ TBoolVector.TReverseEnumerator }

function TBoolVector.TReverseEnumerator.GetCurrent: SizeInt;
begin
  Result := FLimbIndex shl INT_SIZE_LOG + FBitIndex;
end;

function TBoolVector.TReverseEnumerator.FindFirst: Boolean;
var
  I: SizeInt;
begin
  I := FValue^.Bsr;
  if I >= 0 then
    begin
      FLimbIndex := I shr INT_SIZE_LOG;
      FBitIndex := I and INT_SIZE_MASK;
      FCurrLimb := FValue^.FBits[FLimbIndex];
      TBoolVector.ClearBit(FBitIndex, FCurrLimb);
      Result := True;
    end
  else
    begin
      FLimbIndex := -1;
      FBitIndex := BitsizeOf(SizeUInt);
      Result := False;
    end;
end;

function TBoolVector.TReverseEnumerator.MoveNext: Boolean;
begin
  if FInCycle then
    repeat
      FBitIndex := TBoolVector.BsrValue(FCurrLimb);
      Result := FBitIndex >= 0;
      if Result then
        TBoolVector.ClearBit(FBitIndex, FCurrLimb)
      else
        begin
          if FLimbIndex <= 0 then
            exit(False);
          Dec(FLimbIndex);
          FCurrLimb := FValue^.FBits[FLimbIndex];
        end;
    until Result
  else
    begin
      Result := FindFirst;
      FInCycle := True;
    end;
end;

{ TBoolVector.TReverse }

function TBoolVector.TReverse.GetEnumerator: TReverseEnumerator;
begin
  Result.FValue := FValue;
  Result.FInCycle := False;
end;

{ TBoolVector }

function TBoolVector.GetBit(aIndex: SizeInt): Boolean;
begin
  if SizeUInt(aIndex) < SizeUInt(System.Length(FBits) shl INT_SIZE_LOG) then
    Result := (FBits[aIndex shr INT_SIZE_LOG] and (SizeUInt(1) shl (aIndex and INT_SIZE_MASK))) <> 0
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TBoolVector.GetSize: SizeInt;
begin
  Result := System.Length(FBits) shl INT_SIZE_LOG;
end;

procedure TBoolVector.SetBit(aIndex: SizeInt; aValue: Boolean);
begin
  if SizeUInt(aIndex) < SizeUInt(System.Length(FBits) shl INT_SIZE_LOG) then
    begin
      if aValue then
        FBits[aIndex shr INT_SIZE_LOG] :=
          FBits[aIndex shr INT_SIZE_LOG] or (SizeUInt(1) shl (aIndex and INT_SIZE_MASK))
      else
        FBits[aIndex shr INT_SIZE_LOG] :=
          FBits[aIndex shr INT_SIZE_LOG] and not (SizeUInt(1) shl (aIndex and INT_SIZE_MASK));
    end
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TBoolVector.SetSize(aValue: SizeInt);
var
  OldLen: SizeInt;
begin
  OldLen := Size;
  if aValue > OldLen then
    begin
      aValue := aValue shr INT_SIZE_LOG + Ord(aValue and INT_SIZE_MASK <> 0);
      System.SetLength(FBits, aValue);
      System.FillChar(FBits[OldLen], (aValue - OldLen) * SizeOf(SizeUInt), 0);
    end;
end;

class function TBoolVector.BsfValue(aValue: SizeUInt): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := ShortInt(BsfQWord(aValue));
{$ELSEIF DEFINED(CPU32)}
  Result := ShortInt(BsfDWord(aValue));
{$ELSE}
  Result := ShortInt(BsfWord(aValue));
{$ENDIF}
end;

class function TBoolVector.BsrValue(aValue: SizeUInt): SizeInt;
begin
{$IF DEFINED(CPU64)}
  Result := ShortInt(BsrQWord(aValue));
{$ELSEIF DEFINED(CPU32)}
  Result := ShortInt(BsrDWord(aValue));
{$ELSE}
  Result := ShortInt(BsrWord(aValue));
{$ENDIF}
end;

class procedure TBoolVector.ClearBit(aIndex: SizeInt; var aValue: SizeUInt);
begin
  aValue := aValue and not (SizeUInt(1) shl aIndex);
end;

class operator TBoolVector.Copy(constref aSrc: TBoolVector; var aDst: TBoolVector);
begin
  aDst.FBits := System.Copy(aSrc.FBits);
end;

procedure TBoolVector.InitRange(aRange: SizeInt);
var
  msb: SizeInt;
begin
  FBits := nil;
  if aRange > 0 then
    begin
      msb := aRange and INT_SIZE_MASK;
      aRange := aRange shr INT_SIZE_LOG  + Ord(msb <> 0);
      System.SetLength(FBits, aRange);
      System.FillChar(FBits[0], aRange * SizeOf(SizeUInt), $ff);
      if msb <> 0 then
        FBits[Pred(aRange)] := FBits[Pred(aRange)] shr (BitsizeOf(SizeUint) - msb);
    end;
end;

function TBoolVector.GetEnumerator: TEnumerator;
begin
  Result.FValue := @Self;
  Result.FInCycle := False;
end;

function TBoolVector.Reverse: TReverse;
begin
  Result.FValue := @Self;
end;

function TBoolVector.ToArray: TIntArray;
var
  I, Pos: SizeInt;
begin
  System.SetLength(Result, PopCount);
  Pos := 0;
  for I in Self do
    begin
      Result[Pos] := I;
      Inc(Pos);
    end;
end;

procedure TBoolVector.ClearBits;
begin
  if FBits <> nil then
    System.FillChar(FBits[0], System.Length(FBits) * SizeOf(SizeUInt), 0);
end;

procedure TBoolVector.SetBits;
begin
  if FBits <> nil then
    System.FillChar(FBits[0], System.Length(FBits) * SizeOf(SizeUInt), $ff);
end;

function TBoolVector.IsEmpty: Boolean;
var
  I: SizeUInt;
begin
  for I in FBits do
    if I <> 0 then
      exit(False);
  Result := True;
end;

function TBoolVector.NonEmpty: Boolean;
begin
  Result := not IsEmpty;
end;

procedure TBoolVector.SwapBits(var aVector: TBoolVector);
var
  tmp: TBits;
begin
  tmp := FBits;
  FBits := aVector.FBits;
  aVector.FBits := tmp;
end;

function TBoolVector.Bsf: SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBits) do
    if FBits[I] <> 0 then
      exit(I shl INT_SIZE_LOG + BsfValue(FBits[I]));
  Result := -1;
end;

function TBoolVector.Bsr: SizeInt;
var
  I: SizeInt;
begin
  for I := System.High(FBits) downto 0 do
    if FBits[I] <> 0 then
      exit(I shl INT_SIZE_LOG + BsrValue(FBits[I]));
  Result := -1;
end;

function TBoolVector.Lob: SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to System.High(FBits) do
    if FBits[I] <> High(SizeUInt) then
      exit(I shl INT_SIZE_LOG + BsfValue(not FBits[I]));
  Result := -1;
end;

function TBoolVector.Intersecting(constref aValue: TBoolVector): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Math.Min(System.High(FBits), System.High(aValue.FBits)) do
    if FBits[I] and aValue.FBits[I] <> 0 then
      exit(True);
  Result := False;
end;

function TBoolVector.IntersectionPop(constref aValue: TBoolVector): SizeInt;
var
  I, Len: SizeInt;
begin
  Len := Math.Min(System.High(FBits), System.High(aValue.FBits));
  I := 0;
  Result := 0;
  while I <= Len - 4 do
    begin
      Result += SizeInt(PopCnt(FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(FBits[I+1] and aValue.FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2] and aValue.FBits[I+2])) +
                SizeInt(PopCnt(FBits[I+3] and aValue.FBits[I+3]));
      Inc(I, 4);
    end;
  for I := I to Len do
    Result += SizeInt(PopCnt(FBits[I] and aValue.FBits[I]));
end;

function TBoolVector.Contains(constref aValue: TBoolVector): Boolean;
var
  I: SizeInt;
begin
  for I := 0 to Math.Min(System.High(FBits), System.High(aValue.FBits)) do
    if FBits[I] or aValue.FBits[I] <> FBits[I] then
      exit(False);
  for I := System.Length(FBits) to System.High(aValue.FBits) do
    if aValue.FBits[I] <> 0 then
      exit(False);
  Result := True;
end;

function TBoolVector.JoinGain(constref aValue: TBoolVector): SizeInt;
var
  I, Len: SizeInt;
begin
  Len := Math.Min(System.High(FBits), System.High(aValue.FBits));
  I := 0;
  Result := 0;
  while I <= Len - 4 do
    begin
      Result += SizeInt(PopCnt(not FBits[I  ] and aValue.FBits[I  ])) +
                SizeInt(PopCnt(not FBits[I+1] and aValue.FBits[I+1])) +
                SizeInt(PopCnt(not FBits[I+2] and aValue.FBits[I+2])) +
                SizeInt(PopCnt(not FBits[I+3] and aValue.FBits[I+3]));
      Inc(I, 4);
    end;
  while I <= Len do
    begin
      Result += SizeInt(PopCnt(not FBits[I] and aValue.FBits[I]));
      Inc(I);
    end;
  for I := I to System.High(aValue.FBits) do
    Result += SizeInt(PopCnt(aValue.FBits[I]));
end;

procedure TBoolVector.Join(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  I := Succ(aValue.Bsr);
  if I > Size then
    Size := I;
  Len := Pred(I shr INT_SIZE_LOG + Ord(I and INT_SIZE_MASK <> 0));
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] or aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] or aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] or aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] or aValue.FBits[I+3];
      Inc(I, 4);
    end;
  for I := I to Len do
    FBits[I] := FBits[I] or aValue.FBits[I];
end;

function TBoolVector.Union(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Join(aValue);
end;

procedure TBoolVector.Subtract(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  Len := Math.Min(System.High(FBits), System.High(aValue.FBits));
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] and not aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] and not aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] and not aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] and not aValue.FBits[I+3];
      Inc(I, 4);
    end;
  for I := I to Len do
    FBits[I] := FBits[I] and not aValue.FBits[I];
end;

function TBoolVector.Difference(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Subtract(aValue);
end;

procedure TBoolVector.Intersect(constref aValue: TBoolVector);
var
  I, Len: SizeInt;
begin
  Len := Math.Min(System.High(FBits), System.High(aValue.FBits));
  I := 0;
  while I <= Len - 4 do
    begin
      FBits[I  ] := FBits[I  ] and aValue.FBits[I  ];
      FBits[I+1] := FBits[I+1] and aValue.FBits[I+1];
      FBits[I+2] := FBits[I+2] and aValue.FBits[I+2];
      FBits[I+3] := FBits[I+3] and aValue.FBits[I+3];
      Inc(I, 4);
    end;
  for I := I to Len do
    FBits[I] := FBits[I] and aValue.FBits[I];
  for I := Succ(Len) to System.High(FBits) do
    FBits[I] := 0;
end;

function TBoolVector.Intersection(constref aValue: TBoolVector): TBoolVector;
begin
  Result := Self;
  Result.Intersect(aValue);
end;

function TBoolVector.PopCount: SizeInt;
var
  I: SizeInt = 0;
begin
  Result := 0;
  while I <= System.High(FBits) - 4 do
    begin
      Result += SizeInt(PopCnt(FBits[I  ])) + SizeInt(PopCnt(FBits[I+1])) +
                SizeInt(PopCnt(FBits[I+2])) + SizeInt(PopCnt(FBits[I+3]));
      Inc(I, 4);
    end;
  for I := I to  System.High(FBits) do
    Result += SizeInt(PopCnt(FBits[I]));
end;

{ TGVectorHelpUtil }

class procedure TGVectorHelpUtil.Reverse(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Reverse(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGVectorHelpUtil.Reverse(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.Reverse(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class procedure TGVectorHelpUtil.RandomShuffle(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RandomShuffle(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGVectorHelpUtil.RandomShuffle(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.RandomShuffle(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGVectorHelpUtil.SequentSearch(v: TVector; constref aValue: T; c: TEqualityCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGVectorHelpUtil.SequentSearch(constref v: TLiteVector; constref aValue: T;
  c: TEqualityCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;


{ TGBaseVectorHelper }

class function TGBaseVectorHelper.SequentSearch(v: TVector; constref aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.SequentSearch(constref v: TLiteVector; constref aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.BinarySearch(v: TVector; constref aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.BinarySearch(constref v: TLiteVector; constref aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMin(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMin(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMax(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.IndexOfMax(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGBaseVectorHelper.GetMin(v: TVector): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGBaseVectorHelper.GetMin(constref v: TLiteVector): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGBaseVectorHelper.GetMax(v: TVector): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGBaseVectorHelper.GetMax(constref v: TLiteVector): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGBaseVectorHelper.FindMin(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMin(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMax(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMax(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue)
  else
    Result := False;
end;

class function TGBaseVectorHelper.NthSmallest(v: TVector; N: SizeInt): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N);
end;

class function TGBaseVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N);
end;

class function TGBaseVectorHelper.NextPermutation2Asc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Asc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Desc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.NextPermutation2Desc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsNonDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsNonDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsStrictAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsStrictAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsNonAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsNonAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGBaseVectorHelper.IsStrictDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.IsStrictDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.Same(A, B: TVector): Boolean;
var
  c: SizeInt;
begin
  c := A.ElemCount;
  if B.ElemCount = c then
    Result := THelper.Same(A.FItems[0..Pred(c)], B.FItems[0..Pred(c)])
  else
    Result := False;
end;

class function TGBaseVectorHelper.Same(constref A, B: TLiteVector): Boolean;
var
  c: SizeInt;
begin
  c := A.Count;
  if B.Count = c then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(c)], B.FBuffer.FItems[0..Pred(c)])
  else
    Result := False;
end;

class procedure TGBaseVectorHelper.QuickSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.QuickSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.IntroSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.IntroSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.MergeSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.MergeSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGBaseVectorHelper.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGBaseVectorHelper.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class function TGBaseVectorHelper.SelectDistinct(v: TVector): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := nil;
end;

class function TGBaseVectorHelper.SelectDistinct(constref v: TLiteVector): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := nil;
end;

{ TGComparableVectorHelper }

class procedure TGComparableVectorHelper.Reverse(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Reverse(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGComparableVectorHelper.Reverse(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.Reverse(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class procedure TGComparableVectorHelper.RandomShuffle(v: TVector);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.RandomShuffle(v.FItems[0..Pred(v.ElemCount)]);
end;

class procedure TGComparableVectorHelper.RandomShuffle(var v: TLiteVector);
begin
  if v.Count > 1 then
    THelper.RandomShuffle(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.SequentSearch(v: TVector; constref aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.SequentSearch(constref v: TLiteVector; constref aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.BinarySearch(v: TVector; constref aValue: T): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.BinarySearch(constref v: TLiteVector; constref aValue: T): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMin(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMin(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMax(v: TVector): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.IndexOfMax(constref v: TLiteVector): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := -1;
end;

class function TGComparableVectorHelper.GetMin(v: TVector): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGComparableVectorHelper.GetMin(constref v: TLiteVector): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.GetMax(v: TVector): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)]);
end;

class function TGComparableVectorHelper.GetMax(constref v: TLiteVector): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)]);
end;

class function TGComparableVectorHelper.FindMin(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMin(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMax(v: TVector; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMax(constref v: TLiteVector; out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt;
  out aValue: T): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue)
  else
    Result := False;
end;

class function TGComparableVectorHelper.NthSmallest(v: TVector; N: SizeInt): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N);
end;

class function TGComparableVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N);
end;

class function TGComparableVectorHelper.NextPermutation2Asc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Asc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Desc(v: TVector): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.NextPermutation2Desc(var v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsNonDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsNonDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsStrictAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsStrictAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsNonAscending(v: TVector): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsNonAscending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := True;
end;

class function TGComparableVectorHelper.IsStrictDescending(v: TVector): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.IsStrictDescending(constref v: TLiteVector): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.Same(A, B: TVector): Boolean;
var
  c: SizeInt;
begin
  c := A.ElemCount;
  if B.ElemCount = c then
    Result := THelper.Same(A.FItems[0..Pred(c)], B.FItems[0..Pred(c)])
  else
    Result := False;
end;

class function TGComparableVectorHelper.Same(constref A, B: TLiteVector): Boolean;
var
  c: SizeInt;
begin
  c := A.Count;
  if B.Count = c then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(c)], B.FBuffer.FItems[0..Pred(c)])
  else
    Result := False;
end;

class procedure TGComparableVectorHelper.QuickSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.QuickSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.IntroSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.IntroSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.MergeSort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.MergeSort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class procedure TGComparableVectorHelper.Sort(v: TVector; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], o);
end;

class procedure TGComparableVectorHelper.Sort(var v: TLiteVector; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], o);
end;

class function TGComparableVectorHelper.SelectDistinct(v: TVector): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)])
  else
    Result := nil;
end;

class function TGComparableVectorHelper.SelectDistinct(constref v: TLiteVector): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)])
  else
    Result := nil;
end;

{ TGRegularVectorHelper }

class function TGRegularVectorHelper.SequentSearch(v: TVector; constref aValue: T; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.SequentSearch(constref v: TLiteVector; constref aValue: T;
  c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.BinarySearch(v: TVector; constref aValue: T; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.BinarySearch(constref v: TLiteVector; constref aValue: T;
  c: TCompare): SizeInt;
begin

end;

class function TGRegularVectorHelper.IndexOfMin(v: TVector; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.IndexOfMax(v: TVector; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.IndexOfMax(constref v: TLiteVector; c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGRegularVectorHelper.GetMin(v: TVector; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGRegularVectorHelper.GetMin(constref v: TLiteVector; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGRegularVectorHelper.GetMax(v: TVector; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGRegularVectorHelper.GetMax(constref v: TLiteVector; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGRegularVectorHelper.FindMin(v: TVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMax(v: TVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGRegularVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGRegularVectorHelper.NextPermutation2Asc(v: TVector; c: TCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Desc(v: TVector; c: TCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsNonDescending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsNonDescending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsStrictAscending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsNonAscending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsNonAscending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGRegularVectorHelper.IsStrictDescending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.Same(A, B: TVector; c: TCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGRegularVectorHelper.Same(constref A, B: TLiteVector; c: TCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGRegularVectorHelper.QuickSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.QuickSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.IntroSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.IntroSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.MergeSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.MergeSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGRegularVectorHelper.Sort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGRegularVectorHelper.Sort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGRegularVectorHelper.SelectDistinct(v: TVector; c: TCompare): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGRegularVectorHelper.SelectDistinct(constref v: TLiteVector; c: TCompare): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

{ TGDelegatedVectorHelper }

class function TGDelegatedVectorHelper.SequentSearch(v: TVector; constref aValue: T; c: TOnCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.SequentSearch(constref v: TLiteVector; constref aValue: T;
  c: TOnCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.BinarySearch(v: TVector; constref aValue: T; c: TOnCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.BinarySearch(constref v: TLiteVector; constref aValue: T;
  c: TOnCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMin(v: TVector; c: TOnCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMin(constref v: TLiteVector; c: TOnCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMax(v: TVector; c: TOnCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.IndexOfMax(constref v: TLiteVector; c: TOnCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGDelegatedVectorHelper.GetMin(v: TVector; c: TOnCompare): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGDelegatedVectorHelper.GetMin(constref v: TLiteVector; c: TOnCompare): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGDelegatedVectorHelper.GetMax(v: TVector; c: TOnCompare): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGDelegatedVectorHelper.GetMax(constref v: TLiteVector; c: TOnCompare): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGDelegatedVectorHelper.FindMin(v: TVector; out aValue: T; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMax(v: TVector; out aValue: T; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T;
  c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T;
  c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TOnCompare): TOptional;
{%H-}begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGDelegatedVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt;
  c: TOnCompare): TOptional;
{%H-}begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGDelegatedVectorHelper.NextPermutation2Asc(v: TVector; c: TOnCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Desc(v: TVector; c: TOnCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsNonDescending(v: TVector; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsNonDescending(constref v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsStrictAscending(v: TVector; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsStrictAscending(constref v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsNonAscending(v: TVector; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsNonAscending(constref v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGDelegatedVectorHelper.IsStrictDescending(v: TVector; c: TOnCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TOnCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.Same(A, B: TVector; c: TOnCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGDelegatedVectorHelper.Same(constref A, B: TLiteVector; c: TOnCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGDelegatedVectorHelper.QuickSort(v: TVector; c: TOnCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.QuickSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.IntroSort(v: TVector; c: TOnCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.IntroSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.MergeSort(v: TVector; c: TOnCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.MergeSort(var v: TLiteVector; c: TOnCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGDelegatedVectorHelper.Sort(v: TVector; c: TOnCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGDelegatedVectorHelper.Sort(var v: TLiteVector; c: TOnCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGDelegatedVectorHelper.SelectDistinct(v: TVector; c: TOnCompare): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGDelegatedVectorHelper.SelectDistinct(constref v: TLiteVector;
  c: TOnCompare): TLiteVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

{ TGNestedVectorHelper }

class function TGNestedVectorHelper.SequentSearch(v: TVector; constref aValue: T; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.SequentSearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.SequentSearch(constref v: TLiteVector; constref aValue: T;
  c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.SequentSearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.BinarySearch(v: TVector; constref aValue: T; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.BinarySearch(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.BinarySearch(constref v: TLiteVector; constref aValue: T;
  c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.BinarySearch(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMin(v: TVector; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMin(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMin(constref v: TLiteVector; c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMin(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMax(v: TVector; c: TCompare): SizeInt;
begin
  if v.ElemCount > 0 then
    Result := THelper.IndexOfMax(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.IndexOfMax(constref v: TLiteVector; c: TCompare): SizeInt;
begin
  if v.Count > 0 then
    Result := THelper.IndexOfMax(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := -1;
end;

class function TGNestedVectorHelper.GetMin(v: TVector; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMin(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGNestedVectorHelper.GetMin(constref v: TLiteVector; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMin(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGNestedVectorHelper.GetMax(v: TVector; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.GetMax(v.FItems[0..Pred(v.ElemCount)], c);
end;

class function TGNestedVectorHelper.GetMax(constref v: TLiteVector; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.GetMax(v.FBuffer.FItems[0..Pred(v.Count)], c);
end;

class function TGNestedVectorHelper.FindMin(v: TVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMin(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMin(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMin(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMax(v: TVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMax(v.FItems[0..Pred(v.ElemCount)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMax(constref v: TLiteVector; out aValue: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMax(v.FBuffer.FItems[0..Pred(v.Count)], aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMinMax(v: TVector; out aMin, aMax: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindMinMax(v.FItems[0..Pred(v.ElemCount)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindMinMax(constref v: TLiteVector; out aMin, aMax: T; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindMinMax(v.FBuffer.FItems[0..Pred(v.Count)], aMin, aMax, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindNthSmallest(v: TVector; N: SizeInt; out aValue: T; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.FindNthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.FindNthSmallest(constref v: TLiteVector; N: SizeInt; out aValue: T;
  c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.FindNthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, aValue, c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NthSmallest(v: TVector; N: SizeInt; c: TCompare): TOptional;
begin
  if v.ElemCount > 0 then
    Result := THelper.NthSmallestND(v.FItems[0..Pred(v.ElemCount)], N, c);
end;

class function TGNestedVectorHelper.NthSmallest(constref v: TLiteVector; N: SizeInt; c: TCompare): TOptional;
begin
  if v.Count > 0 then
    Result := THelper.NthSmallestND(v.FBuffer.FItems[0..Pred(v.Count)], N, c);
end;

class function TGNestedVectorHelper.NextPermutation2Asc(v: TVector; c: TCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Asc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Asc(var v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Asc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Desc(v: TVector; c: TCompare): Boolean;
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    Result := THelper.NextPermutation2Desc(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.NextPermutation2Desc(var v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.NextPermutation2Desc(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsNonDescending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsNonDescending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsStrictAscending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsStrictAscending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsNonAscending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 0 then
    Result := THelper.IsNonAscending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsNonAscending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 0 then
    Result := THelper.IsNonAscending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := True;
end;

class function TGNestedVectorHelper.IsStrictDescending(v: TVector; c: TCompare): Boolean;
begin
  if v.ElemCount > 1 then
    Result := THelper.IsStrictDescending(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.IsStrictDescending(constref v: TLiteVector; c: TCompare): Boolean;
begin
  if v.Count > 1 then
    Result := THelper.IsStrictDescending(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.Same(A, B: TVector; c: TCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.ElemCount;
  if B.ElemCount = cnt then
    Result := THelper.Same(A.FItems[0..Pred(cnt)], B.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class function TGNestedVectorHelper.Same(constref A, B: TLiteVector; c: TCompare): Boolean;
var
  cnt: SizeInt;
begin
  cnt := A.Count;
  if B.Count = cnt then
    Result := THelper.Same(A.FBuffer.FItems[0..Pred(cnt)], B.FBuffer.FItems[0..Pred(cnt)], c)
  else
    Result := False;
end;

class procedure TGNestedVectorHelper.QuickSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.QuickSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.QuickSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.QuickSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.IntroSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.IntroSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.IntroSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.IntroSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.MergeSort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.MergeSort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.MergeSort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.MergeSort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class procedure TGNestedVectorHelper.Sort(v: TVector; c: TCompare; o: TSortOrder);
begin
  v.CheckInIteration;
  if v.ElemCount > 1 then
    THelper.Sort(v.FItems[0..Pred(v.ElemCount)], c, o);
end;

class procedure TGNestedVectorHelper.Sort(var v: TLiteVector; c: TCompare; o: TSortOrder);
begin
  if v.Count > 1 then
    THelper.Sort(v.FBuffer.FItems[0..Pred(v.Count)], c, o);
end;

class function TGNestedVectorHelper.SelectDistinct(v: TVector; c: TCompare): TVector.TArray;
begin
  if v.ElemCount > 0 then
    Result := THelper.SelectDistinct(v.FItems[0..Pred(v.ElemCount)], c)
  else
    Result := nil;
end;

class function TGNestedVectorHelper.SelectDistinct(constref v: TLiteVector; c: TCompare): TVector.TArray;
begin
  if v.Count > 0 then
    Result := THelper.SelectDistinct(v.FBuffer.FItems[0..Pred(v.Count)], c)
  else
    Result := nil;
end;

end.
