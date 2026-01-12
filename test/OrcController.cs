using DG.Tweening;
using Project.Character;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AI;

public class OrcController : MonoBehaviour
{
    // 몬스터 종류를 정의
    public EntityNames EntityType = EntityNames.Orc;

    [Header("감지 설정")]
    [Tooltip("플레이어를 감지할 수 있는 최대 거리")]
    public float detectionRange = 10f;

    [Header("시야 설정")]
    [Tooltip("몬스터의 시야각 (degrees)")]
    public float viewAngle = 90f;

    [Tooltip("시야 차단 여부를 체크할지 설정")]
    public bool requiresLineOfSight = false;
    
    [Tooltip("몬스터의 공격 가능 거리")]
    public float attackRange = 1f;

    [Tooltip("몬스터의 이동 속도")]
    public float moveSpeed = 2f;

    [Tooltip("몬스터가 플레이어를 바라보는 속도")]
    public float rotationSpeed = 5f;

    [Header("meleeAttackRange")]
    public float meleeAttackRange = 5f;

    private bool Death = false;

    //몬스터와 플레이어 사이의 거리
    private float distanceToPlayer;
    private Health monsterHealth;

    private Vector3 patrolDestination;

    [Header("순찰상태 값")]
    public float stuckCheckInterval = 2f; // 멈춰있는 시간 검증하는 간격
    public float stuckThreshold = 0.5f; // 멈춰있다고 판단하는 거리
    public float stuckTimeLimit = 10f; //멈춰있는 시간이 얼마정도 지나면 다시 새로운 목적지를 설정할지

    private Vector3 lastPosition;
    private float stuckTimer = 0f;
    private float checkTimer = 0f;

    [HideInInspector] public NavMeshAgent navMeshAgent;
    [HideInInspector] public Animator animator;
    [HideInInspector] public Collider collider;

    // 현재 타겟 (주로 플레이어)
    public GameObject Target { get; set; }

    [HideInInspector] public float attackDelay; // 공격 딜레이 시간

    // 현재 상태
    private OrcState currentState;

    //조건에 맞지 않아 공격하지 않았을때 딜레이 시간을 주지 않기 위함
    [HideInInspector] public bool notAttack = false;
    private Dictionary<string, Coroutine> activeCoroutines = new Dictionary<string, Coroutine>();

    // 이 오크가 생성한 돌들을 추적하는 리스트 추가
    [HideInInspector] public List<GameObject> ownedStones = new List<GameObject>();

    // 상태 인스턴스들
    public OrcPatrol PatrolState { get; set; }
    public OrcChase ChaseState { get; set; }
    public OrcIdle idleState { get; set; }
    public OrcGlobalState globalState { get; set; }

    public OrcAttackDelayState AttackDelay { get; set; }
    public OrcStoneThrow stoneThrow { get; set; }
    public OrcRushAttack rushAttack { get; set; }
    public OrcMeleeAttack meleeAttack { get; set; }

    //애니메이션 클립 찾기
    [HideInInspector] public RuntimeAnimatorController animatorController;
    [HideInInspector] public AnimatorStateInfo currentAnimatorState;

    private void Awake()
    {
        DOTween.SetTweensCapacity(500, 50); //닷트윈 사용용량 설정
    }

    void OnEnable()
    {
        Death = false;

        if (monsterHealth != null)
            monsterHealth.NowHealthValue = monsterHealth.MaxHealthValue;

        // 필요하면 FSM 상태도 초기화
        currentState = null;
        ChangeState(new OrcIdle());

        if (navMeshAgent != null)
        {
            navMeshAgent.enabled = true;
            navMeshAgent.isStopped = false;
        }

        if (collider != null)
            collider.enabled = true;
    }

    private void Start()
    {
        animator = GetComponent<Animator>();
        monsterHealth = GetComponent<Health>();
        collider = GetComponent<Collider>();
        animatorController = animator.runtimeAnimatorController;
        

        //찾을려는 대상을 플레이어로 설정
        Target = GameObject.FindGameObjectWithTag("Player");

        //  navMeshAgent 컴포넌트 초기화
        navMeshAgent = GetComponent<NavMeshAgent>();


        // 메시지 핸들러 등록
        MessageDispatcher.Instance.RegisterHandler(EntityType, HandleMessage);

        // 초기 상태 설정
        ChangeState(new OrcIdle());
        ChangeSpeed(moveSpeed);

        //행동상태 초기화
        idleState = new OrcIdle();
        PatrolState = new OrcPatrol();
        ChaseState = new OrcChase();
        globalState = OrcGlobalState.Instance;

        AttackDelay = new OrcAttackDelayState();
        stoneThrow = new OrcStoneThrow();
        rushAttack = new OrcRushAttack();
        meleeAttack = new OrcMeleeAttack();

        EnemyAudioController.FindObjectOfType<EnemyAudioController>().PlaySFX(AudioManager.Instance.audioClipData.orcSpawn_Clip);

        //순찰상태에서 사용할 목적지 초기화
        lastPosition = transform.position;
        stuckTimer = 0f;
        checkTimer = 0f;
    }

    private void FixedUpdate()
    {
        // Patrol 상태에서만 stuck 체크
        if (currentState == PatrolState)
        {
            checkTimer += Time.fixedDeltaTime;
            if (checkTimer >= stuckCheckInterval)
            {
                float moved = Vector3.Distance(transform.position, lastPosition);
                if (moved < stuckThreshold)
                {
                    stuckTimer += checkTimer;
                    if (stuckTimer >= stuckTimeLimit)
                    {
                        // 목적지 재설정
                        Vector3 newDestination = PatrolState.RandomNavSphere(transform.position, 5f, 1);
                        SetPatrolDestination(newDestination);
                        navMeshAgent.SetDestination(newDestination);
                        Debug.Log("멈춤 감지: 새로운 목적지로 재설정");
                        stuckTimer = 0f;
                    }
                }
                else
                {
                    stuckTimer = 0f;
                }
                lastPosition = transform.position;
                checkTimer = 0f;
            }
        }
    }

    private void Update()
    {
        currentAnimatorState = animator.GetCurrentAnimatorStateInfo(0);

        //전역상태 실행
        globalState?.Execute(this);
        //FSM 현재 상태
        currentState?.Execute(this);

        ChangeSpeed(moveSpeed);
        UpdaeAIPath();

        MonsterDie();
    }

    // NavMeshAgent의 상태를 업데이트
    private void UpdaeAIPath()
    {
        if (currentState is OrcPatrol or OrcChase)
        {
            navMeshAgent.isStopped = false;
        }
        else
        {
            navMeshAgent.isStopped = true;
        }
    }

    // 상태 변경 메서드
    public void ChangeState(OrcState newState)
    {
        currentState?.Exit(this); // 현재 상태 종료
        currentState = newState;
        currentState.Enter(this); // 새로운 상태 시작
        Debug.Log($"{gameObject.name} 상태변경: {currentState.GetType().Name}");
    }

    // 이동 속도 변경 메서드
    public void ChangeSpeed(float newSpeed)
    {
        moveSpeed = newSpeed;
        if (navMeshAgent != null)
        {
            navMeshAgent.speed = newSpeed;
        }
    }

    public void OnDamaged()
    {
        if (!Death)
        {
            EnemyAudioController.FindObjectOfType<EnemyAudioController>().PlaySFX(AudioManager.Instance.audioClipData.orcDamage_Clip);
        }
    }

    public void MonsterDie()
    {
        if(Death) return; // 몬스터가 이미 죽었으면 더 이상 처리하지 않음

        if (monsterHealth.Die())
        {
            Death = true;
            
            // 오크가 죽을 때 소유한 모든 돌들을 파괴
            DestroyAllOwnedStones();
            
            FindObjectOfType<QuestManager>().AddKillProgress(EntityType);
            GetComponent<DissolveController>().StartEffect();
            animator.SetTrigger("Die");
            EnemyAudioController.FindObjectOfType<EnemyAudioController>().PlaySFX(AudioManager.Instance.audioClipData.orcDeath_Clip);
        }
    }

    #region 메시지 처리(이벤트)
    // 메시지 처리 메서드
    private bool HandleMessage(Telegram telegram)
    {
        // GlobalState의 OnMessage 먼저 호출
        bool handled = globalState.OnMessage(this, telegram);

        // 현재 상태의 OnMessage도 호출
        if (!handled)
        {
            handled = currentState.OnMessage(this, telegram);
        }
        return handled;
    }

    // 메시지 전송 메서드
    //extraInfo는 어떤 타입이든 가능하니 필요한 정보 아무거나 보내면 된다
    public void SendMessage(EntityNames receiver, MessageType msg, float delay = 0.0f, object extraInfo = null)
    {
        MessageDispatcher.Instance.DispatchMessage(delay, EntityType, receiver, msg, extraInfo);
    }
#endregion
    #region 시야 체크 기능
    public bool IsTargetInSight(GameObject target)
    {
        // 타겟이 null인지 체크
        if (target == null) return false;

        // 현재 위치에서 타겟까지의 방향 벡터 계산
        Vector3 directionToTarget = target.transform.position - transform.position;
        float dotProduct = Vector3.Dot(transform.forward, directionToTarget.normalized);
        float angleThreshold = Mathf.Cos(viewAngle * 0.5f * Mathf.Deg2Rad);

        // 계산된 내적값이 시야각 임계값보다 크거나 같은지 확인
        // 즉, 타겟이 시야각 내에 있는지 확인
        if (dotProduct >= angleThreshold)
        {
            float distanceToTarget = directionToTarget.magnitude;

            // 타겟이 감지 범위 내에 있는지 확인
            if (distanceToTarget <= detectionRange)
            {
                // 시야 차단 확인이 필요한 경우
                if (requiresLineOfSight)
                {
                    RaycastHit hit;
                    // 레이캐스트로 타겟까지 장애물이 있는지 확인
                    if (Physics.Raycast(transform.position, directionToTarget, out hit, detectionRange))
                    {
                        // 타겟이 아니라면 중간에 장애물이 있다는 의미
                        return hit.collider.gameObject == target;
                    }
                    return false;
                }
                return true;
            }
        }
        return false;
    }

    private Vector3 DirFromAngle(float angleInDegrees)
    {
        angleInDegrees += transform.eulerAngles.y;
        return new Vector3(Mathf.Sin(angleInDegrees * Mathf.Deg2Rad), 0, Mathf.Cos(angleInDegrees * Mathf.Deg2Rad));
    }
    #endregion
    #region OrcState 관련 기능들
    //몬스터와 플레이어의 거리를 반환
    public float GetDistanceToPlayer()
    {
        // 경로 계산 중이라면 -1 반환
        if (navMeshAgent.pathPending)
        {
            return -1f; // -1을 반환하여 경로가 아직 준비되지 않았음을 나타냄
        }
        return navMeshAgent.remainingDistance;
    }
    // 딜레이 시간이 필요한 행동에 사용하는 기능
    public void DelayAction(float delayTime, System.Action action, string coroutineKey = null)
    {
        // 이미 실행 중인 코루틴이 있다면 중지
        if (!string.IsNullOrEmpty(coroutineKey) && activeCoroutines.ContainsKey(coroutineKey))
        {
            StopCoroutine(activeCoroutines[coroutineKey]);
            activeCoroutines.Remove(coroutineKey);
        }
        
        Coroutine newCoroutine = StartCoroutine(DelayActionCorutine(delayTime, action));

        // 키가 제공되었다면 딕셔너리에 저장
        if (!string.IsNullOrEmpty(coroutineKey))
        {
            activeCoroutines[coroutineKey] = newCoroutine;
        }
    }
    //딜레이 시간이 필요한 행동에 사용하는 기능
    private IEnumerator DelayActionCorutine(float delayTime, System.Action action)
    {
        yield return new WaitForSeconds(delayTime);
        action?.Invoke();
    }

    #region Idle 상태에서 사용하는 기능들
    // Idle 상태에서 계산한 목적지를 저장하는 메서드
    public void SetPatrolDestination(Vector3 destination)
    {
        patrolDestination = destination;
    }

    // Patrol 상태에서 저장된 목적지를 가져오는 메서드
    public Vector3 GetPatrolDestination()
    {
        return patrolDestination;
    }
    #endregion


    // 몬스터가 타겟을 바라보도록 회전하는 메서드
    public void LookAtTarget()
    {
        if (Target == null) return;

        Vector3 direction = (Target.transform.position - transform.position).normalized;
        direction.y = 0; // y축 회전 방지

        Quaternion lookRotation = Quaternion.LookRotation(direction);

        // Slerp를 사용하여 부드럽게 회전
        transform.rotation = Quaternion.Slerp(transform.rotation, lookRotation, rotationSpeed * Time.deltaTime);
    }

    // 애니메이션 이벤트를 통해 공격 딜레이를 설정
    public void AnimeEnd(AnimationEvent animationEvent)
    {
        Debug.Log($"클립: {animationEvent.animatorClipInfo.clip?.name} 호출됨 - 딜레이: {animationEvent.floatParameter}");
        attackDelay = animationEvent.floatParameter;
        ChangeState(AttackDelay);
    }
    #endregion
    #region 공격 관련 기능등
    // 돌 프리팹을 등록하는 메서드
    public void RegisterStone(GameObject stone)
    {
        if (stone != null && !ownedStones.Contains(stone))
        {
            ownedStones.Add(stone);
        }
    }

    // 돌 프리팹을 제거하는 메서드 (돌이 자연스럽게 파괴될 때 호출)
    public void UnregisterStone(GameObject stone)
    {
        if (ownedStones.Contains(stone))
        {
            ownedStones.Remove(stone);
        }
    }

    // 모든 소유한 돌들을 파괴하는 메서드
    private void DestroyAllOwnedStones()
    {
        if (!Application.isPlaying) return; // 런타임이 아닐 때는 실행하지 않음
        
        for (int i = ownedStones.Count - 1; i >= 0; i--)
        {
            if (ownedStones[i] != null)
            {
                // GameObject는 런타임에서 Destroy 사용
                if (Application.isPlaying)
                {
                    Destroy(ownedStones[i]);
                }
                else
                {
                    // 에디터에서는 DestroyImmediate 사용
                    DestroyImmediate(ownedStones[i]);
                }
            }
        }
        ownedStones.Clear();
    }
    #endregion
    #region 기즈모 - 시각화 기능
    private void OnDrawGizmos()
    {
        // 공격 범위 시각화
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.position, attackRange);

        // 감지 범위 시각화
        Gizmos.color = Color.green;
        Gizmos.DrawWireSphere(transform.position, detectionRange);

        if (currentState is OrcMeleeAttack)
        {
            Gizmos.color = Color.blue;
            Gizmos.DrawWireSphere(transform.position, meleeAttackRange);
        }

        // 시야각 시각화
        Vector3 viewAngleA = DirFromAngle(-viewAngle * 0.5f);
        Vector3 viewAngleB = DirFromAngle(viewAngle * 0.5f);

        Gizmos.color = Color.yellow;
        Gizmos.DrawLine(transform.position, transform.position + viewAngleA * detectionRange);
        Gizmos.DrawLine(transform.position, transform.position + viewAngleB * detectionRange);
    }
    #endregion
}